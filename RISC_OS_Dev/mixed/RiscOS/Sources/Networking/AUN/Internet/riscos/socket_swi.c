/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 * 
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 * 
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
/*
 * Copyright(c) 1994 Acorn Computers Ltd., Cambridge, England
 *
 */
#include "sys/param.h"
#include "sys/errno.h"
#include "sys/uio.h"
#include "sys/mbuf.h"
#include "sys/domain.h"
#include "sys/protosw.h"
#include "sys/socket.h"
#include "sys/socketvar.h"
#include "sys/ioctl.h"
#include "sys/stat.h"
#include "sys/time.h"
#include "sys/kernel.h"
#include "sys/proc.h"
#include "sys/file.h"
#include "sys/signalvar.h"
#include "sys/systm.h"
#include "sys/queue.h"
#include "sys/sysctl.h"

#include "netinet/in.h"
#include "netinet/ip_var.h"
#include "netinet/udp.h"
#include "netinet/udp_var.h"

#include "debug.h"
#include "module.h"
#include "InetHdr.h"

struct socket *socktab[SOCKTABSIZE];

static int getsockslot(void);
static int do_sock_select(struct socket *so, int which);
static int selscan(fd_set *ibits, fd_set *obits, int nfd, int *retval, int *noblock);

int
socketversion(_kernel_swi_regs *r, int *retval)
{
    *retval = Module_VersionNumber;
    return (0);
}

static void setsockslot(int sockid, struct socket *so)
{
    socktab[sockid] = so;
}

/* Should be in kern/uipc_sycall.c */
int
#ifdef __riscos
sendit(s, mp, flags, retsize)
#else
sendit(p, s, mp, flags, retsize)
	register struct proc *p;
#endif
	int s;
	register struct msghdr *mp;
	int flags, *retsize;
{
#ifndef __riscos
	struct file *fp;
#else
	struct socket *so;
#endif
	struct uio auio;
	register struct iovec *iov;
	register int i;
	struct mbuf *to, *control;
	int len, error;
#ifdef KTRACE
	struct iovec *ktriov = NULL;
#endif

#ifdef __riscos
        if ((so = getsock(s)) == 0)
	        return (EBADF);
	else
		error = 0;
#else
	error = getsock(p->p_fd, s, &fp);
	if (error)
		return (error);
#endif
	auio.uio_iov = mp->msg_iov;
	auio.uio_iovcnt = mp->msg_iovlen;
	auio.uio_segflg = UIO_USERSPACE;
	auio.uio_rw = UIO_WRITE;
#ifndef __riscos
	auio.uio_procp = p;
#endif
	auio.uio_offset = 0;			/* XXX */
	auio.uio_resid = 0;
	iov = mp->msg_iov;
	for (i = 0; i < mp->msg_iovlen; i++, iov++) {
		if ((auio.uio_resid += iov->iov_len) < 0)
			return (EINVAL);
	}
	if (mp->msg_name) {
		error = sockargs(&to, mp->msg_name, mp->msg_namelen, MT_SONAME);
		if (error)
			return (error);
	} else
		to = 0;
	if (mp->msg_control) {
		if (mp->msg_controllen < sizeof(struct cmsghdr)
#ifdef COMPAT_OLDSOCK
		    && mp->msg_flags != MSG_COMPAT
#endif
		) {
			error = EINVAL;
			goto bad;
		}
		error = sockargs(&control, mp->msg_control,
		    mp->msg_controllen, MT_CONTROL);
		if (error)
			goto bad;
#ifdef COMPAT_OLDSOCK
		if (mp->msg_flags == MSG_COMPAT) {
			register struct cmsghdr *cm;

			M_PREPEND(control, sizeof(*cm), M_WAIT);
			if (control == 0) {
				error = ENOBUFS;
				goto bad;
			} else {
				cm = mtod(control, struct cmsghdr *);
				cm->cmsg_len = control->m_len;
				cm->cmsg_level = SOL_SOCKET;
				cm->cmsg_type = SCM_RIGHTS;
			}
		}
#endif
	} else
		control = 0;
#ifdef KTRACE
	if (KTRPOINT(p, KTR_GENIO)) {
		int iovlen = auio.uio_iovcnt * sizeof (struct iovec);

		MALLOC(ktriov, struct iovec *, iovlen, M_TEMP, M_WAITOK);
		bcopy((caddr_t)auio.uio_iov, (caddr_t)ktriov, iovlen);
	}
#endif
	len = auio.uio_resid;
#ifdef __riscos
	error = sosend(so, to, &auio,
	    (struct mbuf *)0, control, flags);
#else
	error = sosend((struct socket *)fp->f_data, to, &auio,
	    (struct mbuf *)0, control, flags);
#endif
	if (error) {
		if (auio.uio_resid != len && (error == ERESTART ||
		    error == EINTR || error == EWOULDBLOCK))
			error = 0;
		if (error == EPIPE)
#ifdef __riscos
			psignal(pfind(so->so_pgid), SIGPIPE);
#else
			psignal(p, SIGPIPE);
#endif
	}
	if (error == 0)
		*retsize = len - auio.uio_resid;
#ifdef KTRACE
	if (ktriov != NULL) {
		if (error == 0)
			ktrgenio(p->p_tracep, s, UIO_WRITE,
				ktriov, *retsize, error);
		FREE(ktriov, M_TEMP);
	}
#endif
bad:
	if (to)
		m_freem(to);
	return (error);
}

/* Should be in kern/uipc_syscall.c */
int
recvit(s, mp, namelenp, retsize)
	int s;
	register struct msghdr *mp;
	caddr_t namelenp;
	int *retsize;
{
#ifdef __riscos
	struct socket *so;
#else
	struct file *fp;
#endif
	struct uio auio;
	register struct iovec *iov;
	register int i;
	int len, error;
	struct mbuf *from = 0, *control = 0;
#ifdef KTRACE
	struct iovec *ktriov = NULL;
#endif

#ifdef __riscos
        so = getsock(s);
        if (so == NULL)
                return (EBADF);
        else
        	error = 0;
#else
	error = getsock(p->p_fd, s, &fp);
	if (error)
		return (error);
#endif
	auio.uio_iov = mp->msg_iov;
	auio.uio_iovcnt = mp->msg_iovlen;
	auio.uio_segflg = UIO_USERSPACE;
	auio.uio_rw = UIO_READ;
#ifndef __riscos
	auio.uio_procp = p;
#endif
	auio.uio_offset = 0;			/* XXX */
	auio.uio_resid = 0;
	iov = mp->msg_iov;
	for (i = 0; i < mp->msg_iovlen; i++, iov++) {
		if ((auio.uio_resid += iov->iov_len) < 0)
			return (EINVAL);
	}
#ifdef KTRACE
	if (KTRPOINT(p, KTR_GENIO)) {
		int iovlen = auio.uio_iovcnt * sizeof (struct iovec);

		MALLOC(ktriov, struct iovec *, iovlen, M_TEMP, M_WAITOK);
		bcopy((caddr_t)auio.uio_iov, (caddr_t)ktriov, iovlen);
	}
#endif
	len = auio.uio_resid;
#ifdef __riscos
	error = soreceive(so, &from, &auio,
#else
	error = soreceive((struct socket *)fp->f_data, &from, &auio,
#endif
	    (struct mbuf **)0, mp->msg_control ? &control : (struct mbuf **)0,
	    &mp->msg_flags);
	if (error) {
		if (auio.uio_resid != len && (error == ERESTART ||
		    error == EINTR || error == EWOULDBLOCK))
			error = 0;
	}
#ifdef KTRACE
	if (ktriov != NULL) {
		if (error == 0)
			ktrgenio(p->p_tracep, s, UIO_READ,
				ktriov, len - auio.uio_resid, error);
		FREE(ktriov, M_TEMP);
	}
#endif
	if (error)
		goto out;
	*retsize = len - auio.uio_resid;
	if (mp->msg_name) {
		len = mp->msg_namelen;
		if (len <= 0 || from == 0)
			len = 0;
		else {
#ifdef COMPAT_OLDSOCK
			if (mp->msg_flags & MSG_COMPAT)
				mtod(from, struct osockaddr *)->sa_family =
				    mtod(from, struct sockaddr *)->sa_family;
#endif
			if (len > from->m_len)
				len = from->m_len;
			/* else if len < from->m_len ??? */
			error = copyout(mtod(from, caddr_t),
			    (caddr_t)mp->msg_name, (unsigned)len);
			if (error)
				goto out;
		}
		mp->msg_namelen = len;
		if (namelenp &&
		    (error = copyout((caddr_t)&len, namelenp, sizeof (int)))) {
#ifdef COMPAT_OLDSOCK
			if (mp->msg_flags & MSG_COMPAT)
				error = 0;	/* old recvfrom didn't check */
			else
#endif
			goto out;
		}
	}
	if (mp->msg_control) {
#ifdef COMPAT_OLDSOCK
		/*
		 * We assume that old recvmsg calls won't receive access
		 * rights and other control info, esp. as control info
		 * is always optional and those options didn't exist in 4.3.
		 * If we receive rights, trim the cmsghdr; anything else
		 * is tossed.
		 */
		if (control && mp->msg_flags & MSG_COMPAT) {
			if (mtod(control, struct cmsghdr *)->cmsg_level !=
			    SOL_SOCKET ||
			    mtod(control, struct cmsghdr *)->cmsg_type !=
			    SCM_RIGHTS) {
				mp->msg_controllen = 0;
				goto out;
			}
			control->m_len -= sizeof (struct cmsghdr);
			control->m_off += sizeof (struct cmsghdr);
		}
#endif
		len = mp->msg_controllen;
		if (len <= 0 || control == 0)
			len = 0;
		else {
			if (len >= control->m_len)
				len = control->m_len;
			else
				mp->msg_flags |= MSG_CTRUNC;
			error = copyout((caddr_t)mtod(control, caddr_t),
			    (caddr_t)mp->msg_control, (unsigned)len);
		}
		mp->msg_controllen = len;
	}
out:
	if (from)
		m_freem(from);
	if (control)
		m_freem(control);
	return (error);
}

struct socket_args {
	int	domain;
	int	type;
	int	protocol;
};
int
socket(uap, retval)
	register struct socket_args *uap;
	int *retval;
{
	struct socket *so;
	int fd, error;

	fd = getsockslot();
	if (fd < 0)
		return (EMFILE);
	error = socreate(uap->domain, &so, uap->type, uap->protocol);
	if (error) {
		/* Do nothing */
	} else {
		*retval = fd;
		setsockslot(fd, so);
		so->so_pgid = fd+1;
	}
	return (error);
}

struct bind_args {
	int	s;
	caddr_t	name;
	int	namelen;
};
/* ARGSUSED */
int
bind(uap)
	register struct bind_args *uap;
{
	struct socket *so;
	struct mbuf *nam;
	int error;

	if ((so = getsock(uap->s)) == 0)
		return (EBADF);
	error = sockargs(&nam, uap->name, uap->namelen, MT_SONAME);
	if (error)
		return (error);
	error = sobind(so, nam);
	m_freem(nam);
	return (error);
}

struct listen_args {
	int	s;
	int	backlog;
};
/* ARGSUSED */
int
listen(uap, retval)
	register struct listen_args *uap;
	int *retval;
{
	struct socket *so;

	so = getsock(uap->s);
	if (so == 0)
		return (EBADF);

	return (solisten(so, uap->backlog));
}

struct accept_args {
	int	s;
	caddr_t	name;
	int	*anamelen;
#ifdef COMPAT_OLDSOCK
	int	compat_43;	/* pseudo */
#endif
};

#ifndef COMPAT_OLDSOCK
#  define	accept1	accept
#endif  /* COMPAT_OLDSOCK*/
int
accept1(uap, retval)
	register struct accept_args *uap;
	int *retval;
{
	struct mbuf *nam;
	int namelen, error, sockid;
	register struct socket *so;

	if (uap->name) {
		error = copyin((caddr_t)uap->anamelen, (caddr_t)&namelen,
			sizeof (namelen));
		if(error)
			return (error);
	}
	so = getsock(uap->s);
	if (so == 0)
		return (EBADF);
	else
		error = 0;

	if ((so->so_options & SO_ACCEPTCONN) == 0)
		return (EINVAL);

	if ((so->so_state & SS_NBIO) && so->so_qlen == 0)
		return (EWOULDBLOCK);

	while (so->so_qlen == 0 && so->so_error == 0) {
		if (so->so_state & SS_CANTRCVMORE) {
			so->so_error = ECONNABORTED;
			break;
		}
		error = tsleep((caddr_t)&so->so_timeo, PSOCK | PCATCH,
		    netcon, 0, so->so_state & SS_SLEEPTW);
		if (error)
			return (error);
	}

	if (so->so_error) {
		error = so->so_error;
		so->so_error = 0;
		return (error);
	}
	sockid = getsockslot();
	if (sockid < 0)
		return (EBADF);
	{ struct socket *aso = so->so_q;
	  if (soqremque(aso, 1) == 0) {
		panic("accept");
		return (EFAULT);
	  }
	  so = aso;
	}
	nam = m_get(M_WAIT, MT_SONAME);
	if (nam == NULL)
		return (ENOBUFS);
	(void) soaccept(so, nam);

	setsockslot(sockid, so);
	so->so_pgid = sockid+1;
	*retval = sockid;

	if (uap->name) {
#ifdef COMPAT_OLDSOCK
		if (uap->compat_43)
			mtod(nam, struct osockaddr *)->sa_family =
			    mtod(nam, struct sockaddr *)->sa_family;
#endif
		if (namelen > nam->m_len)
			namelen = nam->m_len;
		/* SHOULD COPY OUT A CHAIN HERE */
		error = copyout(mtod(nam, caddr_t), (caddr_t)(uap->name),
		    (u_int)namelen);
		if (!error)
			error = copyout((caddr_t)&namelen,
			    (caddr_t)(uap->anamelen), sizeof (*uap->anamelen));
	}
	m_freem(nam);
	return (error);
}

#ifdef COMPAT_OLDSOCK
int
accept(uap, retval)
	struct accept_args *uap;
	int *retval;
{

#ifdef __riscos
	/* Preserve this register (yuck!) */
	int temp = uap->compat_43, error;
	uap->compat_43 = 0;
	error = accept1(uap, retval);
	uap->compat_43 = temp;
	return (error);
#else
	uap->compat_43 = 0;
	return (accept1(uap, retval));
#endif
}

int
oaccept(uap, retval)
	struct accept_args *uap;
	int *retval;
{

#ifdef __riscos
	/* Preserve this register (yuck!) */
	int temp = uap->compat_43, error;
	uap->compat_43 = 1;
	error = accept1(uap, retval);
	uap->compat_43 = temp;
	return (error);
#else
	uap->compat_43 = 1;
	return (accept1(uap, retval));
#endif
}
#endif /* COMPAT_OLDSOCK */


struct connect_args {
	int	s;
	caddr_t	name;
	int	namelen;
};
/* ARGSUSED */
int
connect(uap)
	register struct connect_args *uap;
{
	register struct socket *so;
	struct mbuf *nam;
	int error;

	so = getsock(uap->s);
	if (so == 0)
		return (EBADF);

	if ((so->so_state & SS_NBIO) && (so->so_state & SS_ISCONNECTING))
		return (EALREADY);

	error = sockargs(&nam, uap->name, uap->namelen, MT_SONAME);
	if (error)
		return (error);
	error = soconnect(so, nam);
	if (error)
		goto bad;
	if ((so->so_state & SS_NBIO) && (so->so_state & SS_ISCONNECTING)) {
		m_freem(nam);
		return (EINPROGRESS);
	}
	while ((so->so_state & SS_ISCONNECTING) && so->so_error == 0) {
		error = tsleep((caddr_t)&so->so_timeo, PSOCK | PCATCH,
		    netcon, 0, so->so_state & SS_SLEEPTW);
		if (error)
			break;
	}
	if (error == 0) {
		error = so->so_error;
		so->so_error = 0;
	}
bad:
	so->so_state &= ~SS_ISCONNECTING;
	m_freem(nam);
	if (error == ERESTART)
		error = EINTR;
	return (error);
}

struct sendtosm_args {
	int      s;
	caddr_t *buf;
	u_int    len;
	caddr_t *buf1;
	u_int    len1;
	caddr_t  to;
};
int
sendtosm(uap)
	struct sendtosm_args *uap;
{
	struct socket *so;
	struct mbuf *to, *m, *n;
	int error;

	so = getsock(uap->s);
    	if (so == 0)
		return (EBADF);

    	error = sockargs(&to, uap->to, sizeof(struct sockaddr), MT_SONAME);
    	if (error)
		return (error);

    	m = 0; n = 0;

    	m = ALLOC_U(uap->len, uap->buf);
    	if (m == NULL) {
#ifdef DEBUG
		if (DODEBUG(DBGMMAN))
	    		Printf("sosendsm: ALLOC_U#1 failed\n");
#endif
		error = ENOBUFS;
		goto release;
    	}
    	m->m_type = MT_DATA;
    	m->m_flags = M_PKTHDR;
    	m->m_pkthdr.len = uap->len;
    	m->m_pkthdr.rcvif = (struct ifnet *) 0;

	if (uap->len1 > 0) {
		n = ALLOC_U(uap->len1, uap->buf1);
		if (n == NULL) {
#ifdef DEBUG
	    		if (DODEBUG(DBGMMAN))
				Printf("sosendsm: ALLOC_U#2 failed\n");
#endif
	    		error = ENOBUFS;
	    		goto release;
		}

		n->m_type = MT_DATA;
		n->m_flags = 0;
		m->m_pkthdr.len += uap->len1;
    	        m->m_next = n;
    	}

    	error = udp_usrreq(so, PRU_SEND, m, to, 0);
    	m = 0;

release:
    	if (m)
		m_freem(m);

    	m_freem(to);
    	return (error);
}

struct sendto_args {
	int	s;
	caddr_t	buf;
	size_t	len;
	int	flags;
	caddr_t	to;
	int	tolen;
};
int
sendto(register struct sendto_args *uap, int *retval)
{
        struct msghdr msg;
        struct iovec aiov;

        msg.msg_name = uap->to;
        msg.msg_namelen = uap->tolen;
        msg.msg_iov = &aiov;
        msg.msg_iovlen = 1;
	msg.msg_control = 0;
#ifdef COMPAT_OLDSOCK
	msg.msg_flags = 0;
#endif
        aiov.iov_base = uap->buf;
        aiov.iov_len = uap->len;

        /* TRACE */
#ifdef DEBUGSEND
        Printf("sendit: %d bytes to '%.*s'\n", uap->len, uap->tolen, uap->to);
#endif

        return (sendit(uap->s, &msg, uap->flags, retval));
}

#ifdef COMPAT_OLDSOCK
struct osend_args {
	int	s;
	caddr_t	buf;
	int	len;
	int	flags;
};
int
osend(uap, retval)
	register struct osend_args *uap;
	int *retval;
{
	struct msghdr msg;
	struct iovec aiov;

	msg.msg_name = 0;
	msg.msg_namelen = 0;
	msg.msg_iov = &aiov;
	msg.msg_iovlen = 1;
	aiov.iov_base = uap->buf;
	aiov.iov_len = uap->len;
	msg.msg_control = 0;
	msg.msg_flags = 0;
	return (sendit(uap->s, &msg, uap->flags, retval));
}

struct osendmsg_args {
	int	s;
	caddr_t	msg;
	int	flags;
};
int
osendmsg(uap, retval)
	register struct osendmsg_args *uap;
	int *retval;
{
	struct msghdr msg;
	struct iovec aiov[UIO_SMALLIOV], *iov;
	int error;

	error = copyin(uap->msg, (caddr_t)&msg, sizeof (struct omsghdr));
	if (error)
		return (error);
	if ((u_int)msg.msg_iovlen >= UIO_SMALLIOV) {
		if ((u_int)msg.msg_iovlen >= UIO_MAXIOV)
			return (EMSGSIZE);
		MALLOC(iov, struct iovec *,
		      sizeof(struct iovec) * (u_int)msg.msg_iovlen, M_IOV,
		      M_WAITOK);
		if (iov == NULL)
			return (ENOBUFS);
	} else
		iov = aiov;
	error = copyin((caddr_t)msg.msg_iov, (caddr_t)iov,
	    (unsigned)(msg.msg_iovlen * sizeof (struct iovec)));
	if (error)
		goto done;
	msg.msg_flags = MSG_COMPAT;
	msg.msg_iov = iov;
	error = sendit(uap->s, &msg, uap->flags, retval);
done:
	if (iov != aiov)
		FREE(iov, M_IOV);
	return (error);
}
#endif

struct sendmsg_args {
	int	s;
	caddr_t	msg;
	int	flags;
};
int
sendmsg(uap, retval)
	register struct sendmsg_args *uap;
	int *retval;
{
	struct msghdr msg;
	struct iovec aiov[UIO_SMALLIOV], *iov;
	int error;

	error = copyin(uap->msg, (caddr_t)&msg, sizeof (msg));
	if (error)
		return (error);
	if ((u_int)msg.msg_iovlen >= UIO_SMALLIOV) {
		if ((u_int)msg.msg_iovlen >= UIO_MAXIOV)
			return (EMSGSIZE);
		MALLOC(iov, struct iovec *,
		       sizeof(struct iovec) * (u_int)msg.msg_iovlen, M_IOV,
		       M_WAITOK);
		if (iov == NULL)
			return (ENOBUFS);
	} else
		iov = aiov;
	if (msg.msg_iovlen &&
	    (error = copyin((caddr_t)msg.msg_iov, (caddr_t)iov,
	    (unsigned)(msg.msg_iovlen * sizeof (struct iovec)))))
		goto done;
	msg.msg_iov = iov;
#ifdef COMPAT_OLDSOCK
	msg.msg_flags = 0;
#endif
	error = sendit(uap->s, &msg, uap->flags, retval);
done:
	if (iov != aiov)
		FREE(iov, M_IOV);
	return (error);
}

struct recvfrom_args {
	int	s;
	caddr_t	buf;
	size_t	len;
	int	flags;
	caddr_t	from;
	int	*fromlenaddr;
};

int
recvfrom(register struct recvfrom_args *uap, int *retval)
{
    	struct msghdr msg;
    	struct iovec aiov;
    	int error;

	if (uap->fromlenaddr) {
		error = copyin((caddr_t)uap->fromlenaddr,
		    (caddr_t)&msg.msg_namelen, sizeof (msg.msg_namelen));
		if (error)
			return (error);
	} else
		msg.msg_namelen = 0;
	msg.msg_name = uap->from;
	msg.msg_iov = &aiov;
	msg.msg_iovlen = 1;
	aiov.iov_base = uap->buf;
	aiov.iov_len = uap->len;
	msg.msg_control = 0;
	msg.msg_flags = uap->flags;
	return (recvit(uap->s, &msg, (caddr_t)uap->fromlenaddr, retval));
}

#ifdef COMPAT_OLDSOCK
int
orecvfrom(uap, retval)
	struct recvfrom_args *uap;
	int *retval;
{

	uap->flags |= MSG_COMPAT;
	return (recvfrom(uap, retval));
}
#endif


#ifdef COMPAT_OLDSOCK
struct orecv_args {
	int	s;
	caddr_t	buf;
	int	len;
	int	flags;
};
int
orecv(uap, retval)
	register struct orecv_args *uap;
	int *retval;
{
	struct msghdr msg;
	struct iovec aiov;

	msg.msg_name = 0;
	msg.msg_namelen = 0;
	msg.msg_iov = &aiov;
	msg.msg_iovlen = 1;
	aiov.iov_base = uap->buf;
	aiov.iov_len = uap->len;
	msg.msg_control = 0;
	msg.msg_flags = uap->flags;
	return (recvit(uap->s, &msg, (caddr_t)0, retval));
}

/*
 * Old recvmsg.  This code takes advantage of the fact that the old msghdr
 * overlays the new one, missing only the flags, and with the (old) access
 * rights where the control fields are now.
 */
struct orecvmsg_args {
	int	s;
	struct	omsghdr *msg;
	int	flags;
};
int
orecvmsg(uap, retval)
	register struct orecvmsg_args *uap;
	int *retval;
{
	struct msghdr msg;
	struct iovec aiov[UIO_SMALLIOV], *iov;
	int error;

	error = copyin((caddr_t)uap->msg, (caddr_t)&msg,
	    sizeof (struct omsghdr));
	if (error)
		return (error);
	if ((u_int)msg.msg_iovlen >= UIO_SMALLIOV) {
		if ((u_int)msg.msg_iovlen >= UIO_MAXIOV)
			return (EMSGSIZE);
		MALLOC(iov, struct iovec *,
		      sizeof(struct iovec) * (u_int)msg.msg_iovlen, M_IOV,
		      M_WAITOK);
		if (iov == NULL)
			return (ENOBUFS);
	} else
		iov = aiov;
	msg.msg_flags = uap->flags | MSG_COMPAT;
	error = copyin((caddr_t)msg.msg_iov, (caddr_t)iov,
	    (unsigned)(msg.msg_iovlen * sizeof (struct iovec)));
	if (error)
		goto done;
	msg.msg_iov = iov;
	error = recvit(uap->s, &msg, (caddr_t)&uap->msg->msg_namelen, retval);

	if (msg.msg_controllen && error == 0)
		error = copyout((caddr_t)&msg.msg_controllen,
		    (caddr_t)&uap->msg->msg_accrightslen, sizeof (int));
done:
	if (iov != aiov)
		FREE(iov, M_IOV);
	return (error);
}
#endif

struct recvmsg_args {
	int	s;
	struct	msghdr *msg;
	int	flags;
};
int
recvmsg(uap, retval)
	register struct recvmsg_args *uap;
	int *retval;
{
	struct msghdr msg;
	struct iovec aiov[UIO_SMALLIOV], *uiov, *iov;
	register int error;

	error = copyin((caddr_t)uap->msg, (caddr_t)&msg, sizeof (msg));
	if (error)
		return (error);
	if ((u_int)msg.msg_iovlen >= UIO_SMALLIOV) {
		if ((u_int)msg.msg_iovlen >= UIO_MAXIOV)
			return (EMSGSIZE);
		MALLOC(iov, struct iovec *,
		       sizeof(struct iovec) * (u_int)msg.msg_iovlen, M_IOV,
		       M_WAITOK);
		if (iov == NULL)
			return (ENOBUFS);
	} else
		iov = aiov;
#ifdef COMPAT_OLDSOCK
	msg.msg_flags = uap->flags &~ MSG_COMPAT;
#else
	msg.msg_flags = uap->flags;
#endif
	uiov = msg.msg_iov;
	msg.msg_iov = iov;
	error = copyin((caddr_t)uiov, (caddr_t)iov,
	    (unsigned)(msg.msg_iovlen * sizeof (struct iovec)));
	if (error)
		goto done;
	error = recvit(uap->s, &msg, (caddr_t)0, retval);
	if (!error) {
		msg.msg_iov = uiov;
		error = copyout((caddr_t)&msg, (caddr_t)uap->msg, sizeof(msg));
	}
done:
	if (iov != aiov)
		FREE(iov, M_IOV);
	return (error);
}

struct shutdown_args {
	int	s;
	int	how;
};
int
shutdown(uap)
	register struct shutdown_args *uap;
{
	struct socket *so;

	so = getsock(uap->s);
	if (so == NULL)
		return (EBADF);

	return (soshutdown(so, uap->how));
}

struct setsockopt_args {
	int	s;
	int	level;
	int	name;
	caddr_t	val;
	int	valsize;
};
/* ARGSUSED */
int
setsockopt(uap, retval)
	register struct setsockopt_args *uap;
	int *retval;
{
	struct socket *so;
	struct mbuf *m = NULL;
	int error;

	so = getsock(uap->s);
	if (so == NULL)
		return (EBADF);

	if (uap->valsize > MINCONTIG)
		return (EINVAL);
	if (uap->val) {
		m = ALLOC_S(uap->valsize, NULL);
		if (m == NULL)
			return (ENOBUFS);
		m->m_type = MT_SOOPTS;
		error = copyin(uap->val, mtod(m, caddr_t), (u_int)uap->valsize);
		if (error) {
			(void) m_free(m);
			return (error);
		}
	}
	return (sosetopt(so, uap->level, uap->name, m));
}

struct getsockopt_args {
	int	s;
	int	level;
	int	name;
	caddr_t	val;
	int	*avalsize;
};
/* ARGSUSED */
int
getsockopt(uap, retval)
	register struct getsockopt_args *uap;
	int *retval;
{
	struct socket *so;
	struct mbuf *m = NULL, *m0;
	int op, i, valsize, error;

	so = getsock(uap->s);
	if (so == NULL)
		return (EBADF);
	if (uap->val) {
		error = copyin((caddr_t)uap->avalsize, (caddr_t)&valsize,
		    sizeof (valsize));
		if (error)
			return (error);
	} else
		valsize = 0;
	if ((error = sogetopt(so, uap->level,
	    uap->name, &m)) == 0 && uap->val && valsize && m != NULL) {
		op = 0;
		while (m && !error && op < valsize) {
			i = min(m->m_len, (valsize - op));
			error = copyout(mtod(m, caddr_t), uap->val, (u_int)i);
			op += i;
			uap->val += i;
			m0 = m;
			MFREE(m0,m);
		}
		valsize = op;
		if (error == 0)
			error = copyout((caddr_t)&valsize,
			    (caddr_t)uap->avalsize, sizeof (valsize));
	}
	if (m != NULL)
		(void) m_free(m);
	return (error);
}

/*
 * Get socket name.
 */
struct getsockname_args {
	int	fdes;
	caddr_t	asa;
	int	*alen;
#ifdef COMPAT_OLDSOCK
	int	compat_43;	/* pseudo */
#endif
};

#ifndef COMPAT_OLDSOCK
#define	getsockname1	getsockname
#endif

/* ARGSUSED */
int
getsockname1(uap, retval)
	register struct getsockname_args *uap;
	int *retval;
{
	register struct socket *so;
	struct mbuf *m;
	int len, error;

	so = getsock(uap->fdes);
	if (so == NULL)
		return (EBADF);
	error = copyin((caddr_t)uap->alen, (caddr_t)&len, sizeof (len));
	if (error)
		return (error);
	m = ALLOC_C(0, NULL);
	if (m == NULL)
		return (ENOBUFS);
	m->m_type = MT_SONAME;
	error = (*so->so_proto->pr_usrreq)(so, PRU_SOCKADDR, 0, m, 0);
	if (error)
		goto bad;
	if (len > m->m_len)
		len = m->m_len;
#ifdef COMPAT_OLDSOCK
	if (uap->compat_43)
		mtod(m, struct osockaddr *)->sa_family =
		    mtod(m, struct sockaddr *)->sa_family;
#endif
	error = copyout(mtod(m, caddr_t), (caddr_t)uap->asa, (u_int)len);
	if (error == 0)
		error = copyout((caddr_t)&len, (caddr_t)uap->alen,
		    sizeof (len));
bad:
	m_freem(m);
	return (error);
}

#ifdef COMPAT_OLDSOCK
int
getsockname(uap, retval)
	struct getsockname_args *uap;
	int *retval;
{

#ifdef __riscos
	/* Preserve this register (yuck!) */
	int temp = uap->compat_43, error;
	uap->compat_43 = 0;
	error = getsockname1(uap, retval);
	uap->compat_43 = temp;
	return (error);
#else
	uap->compat_43 = 0;
	return (getsockname1(uap, retval));
#endif
}

int
ogetsockname(uap, retval)
	struct getsockname_args *uap;
	int *retval;
{

#ifdef __riscos
	/* Preserve this register (yuck!) */
	int temp = uap->compat_43, error;
	uap->compat_43 = 1;
	error = getsockname1(uap, retval);
	uap->compat_43 = temp;
	return (error);
#else
	uap->compat_43 = 1;
	return (getsockname1(uap, retval));
#endif
}
#endif /* COMPAT_OLDSOCK */

/*
 * Get name of peer for connected socket.
 */
struct getpeername_args {
	int	fdes;
	caddr_t	asa;
	int	*alen;
#ifdef COMPAT_OLDSOCK
	int	compat_43;	/* pseudo */
#endif
};


#ifndef COMPAT_OLDSOCK
#define	getpeername1	getpeername
#endif

/* ARGSUSED */
int
getpeername1(uap, retval)
	register struct getpeername_args *uap;
	int *retval;
{
	register struct socket *so;
	struct mbuf *m;
	int len, error;

	so = getsock(uap->fdes);
	if (so == NULL)
		return (EBADF);
	if ((so->so_state & (SS_ISCONNECTED|SS_ISCONFIRMING)) == 0)
		return (ENOTCONN);
	error = copyin((caddr_t)uap->alen, (caddr_t)&len, sizeof (len));
	if (error)
		return (error);
	m = ALLOC_C(0, NULL);
	if (m == NULL)
		return (ENOBUFS);
	m->m_type = MT_SONAME;
	error = (*so->so_proto->pr_usrreq)(so, PRU_PEERADDR, 0, m, 0);
	if (error)
		goto bad;
	if (len > m->m_len)
		len = m->m_len;
#ifdef COMPAT_OLDSOCK
	if (uap->compat_43)
		mtod(m, struct osockaddr *)->sa_family =
		    mtod(m, struct sockaddr *)->sa_family;
#endif
	error = copyout(mtod(m, caddr_t), (caddr_t)uap->asa, (u_int)len);
	if (error)
		goto bad;
	error = copyout((caddr_t)&len, (caddr_t)uap->alen, sizeof (len));
bad:
	m_freem(m);
	return (error);
}

#ifdef COMPAT_OLDSOCK
int
getpeername(uap, retval)
	struct getpeername_args *uap;
	int *retval;
{

#ifdef __riscos
	/* Preserve this register (yuck!) */
	int temp = uap->compat_43, error;
	uap->compat_43 = 0;
	error = getpeername1(uap, retval);
	uap->compat_43 = temp;
	return (error);
#else
	uap->compat_43 = 0;
	return (getpeername1(uap, retval));
#endif
}

int
ogetpeername(uap, retval)
	struct getpeername_args *uap;
	int *retval;
{

#ifdef __riscos
	/* Preserve this register (yuck!) */
	int temp = uap->compat_43, error;
	uap->compat_43 = 1;
	error = getpeername1(uap, retval);
	uap->compat_43 = temp;
	return (error);
#else
	uap->compat_43 = 1;
	return (getpeername1(uap, retval));
#endif
}
#endif /* COMPAT_OLDSOCK */
int
sockargs(mp, buf, buflen, type)
	struct mbuf **mp;
	caddr_t buf;
	int buflen, type;
{
	register struct sockaddr *sa;
	register struct mbuf *m;
	int error;

	if ((u_int)buflen > MINCONTIG) {
#if defined(COMPAT_OLDSOCK) && !defined(__riscos)
		if (type == MT_SONAME && (u_int)buflen <= 112)
			buflen = MLEN;		/* unix domain compat. hack */
		else
#endif
		return (EINVAL);
	}
	m = ALLOC(buflen, NULL);
	if (m == NULL)
		return (ENOBUFS);
	m->m_type = type;
	error = copyin(buf, mtod(m, caddr_t), (u_int)buflen);
	if (error)
		m_free(m);
	else {
		*mp = m;
		if (type == MT_SONAME) {
			sa = mtod(m, struct sockaddr *);

#if defined(COMPAT_OLDSOCK) && BYTE_ORDER != BIG_ENDIAN
			if (sa->sa_family == 0 && sa->sa_len < AF_MAX)
				sa->sa_family = sa->sa_len;
#endif
			sa->sa_len = buflen;
		}
	}
	return (error);
}

int
socketclose(int *r)
{
    struct a
    {
	int s;
    } *up = (struct a *)r;
    struct socket *so;
    int sockid;
    int error;

    sockid = up->s;
    if ((so = getsock(sockid)) == 0)
	return (EBADF);

    /* KJB - stop events going off after close */
    so->so_pgid = 0;
    error = soclose(so);
    setsockslot(sockid, (struct socket *)0);
#ifdef DELAY_EVENTS
    siglist[sockid] = 0;
#endif

    return (error);
}

/*
 * Ioctl system call
 */
struct ioctl_args {
	int	fd;
	int	com;
	caddr_t	data;
};
/* ARGSUSED */
int
socketioctl(uap)
	register struct ioctl_args *uap;
{
#ifdef __riscos
	register struct socket *so;
#else
	register struct file *fp;
	register struct filedesc *fdp;
	int tmp;
#endif
	register int com, error;
	register u_int size;
	caddr_t data, memp;
#define STK_PARAMS	128
	char stkbuf[STK_PARAMS];

#ifdef __riscos
	if ((so = getsock(uap->fd)) == 0)
		return (EBADF);

	com = uap->com;
#else
	fdp = p->p_fd;
	if ((u_int)uap->fd >= fdp->fd_nfiles ||
	    (fp = fdp->fd_ofiles[uap->fd]) == NULL)
		return (EBADF);

	if ((fp->f_flag & (FREAD | FWRITE)) == 0)
		return (EBADF);

	switch (com = uap->com) {
	case FIONCLEX:
		fdp->fd_ofileflags[uap->fd] &= ~UF_EXCLOSE;
		return (0);
	case FIOCLEX:
		fdp->fd_ofileflags[uap->fd] |= UF_EXCLOSE;
		return (0);
	}
#endif

	/*
	 * Interpret high order word to find amount of data to be
	 * copied to/from the user's address space.
	 */
	size = IOCPARM_LEN(com);
	if (size > IOCPARM_MAX)
		return (ENOTTY);
	memp = NULL;
#ifdef COMPAT_IBCS2
	if (size + IBCS2_RETVAL_SIZE > sizeof (stkbuf)) {
		memp = (caddr_t)malloc((u_long)size + IBCS2_RETVAL_SIZE,
				       M_IOCTLOPS, M_WAITOK);
		if (memp==0)
			return (ENOBUFS);
		data = memp + IBCS2_RETVAL_SIZE;
	} else
		data = stkbuf + IBCS2_RETVAL_SIZE;
	*(int *)(data - IBCS2_RETVAL_SIZE) = IBCS2_MAGIC_IN;
	*(int *)(data - (IBCS2_RETVAL_SIZE - sizeof(int))) = 0;
	*(int *)(data - (IBCS2_RETVAL_SIZE - 2*sizeof(int))) = 0;
#else
	if (size > sizeof (stkbuf)) {
		memp = (caddr_t)malloc((u_long)size, M_IOCTLOPS, M_WAITOK);
		if (memp==0)
			return (ENOBUFS);
		data = memp;
	} else
		data = stkbuf;
#endif
	if (com&IOC_IN) {
		if (size) {
			error = copyin(uap->data, data, (u_int)size);
			if (error) {
				if (memp)
					free(memp, M_IOCTLOPS);
				return (error);
			}
		} else
			*(caddr_t *)data = uap->data;
	} else if ((com&IOC_OUT) && size)
		/*
		 * Zero the buffer so the user always
		 * gets back something deterministic.
		 */
		bzero(data, size);
	else if (com&IOC_VOID)
		*(caddr_t *)data = uap->data;
#ifdef COMPAT_IBCS2
	else if (com)
		/*
		 * Pick up such things as NIOCxx.
		 * Any copyouts will have to be done prior
		 * to return by their servicing code.
		 */
		*(caddr_t *)data = uap->data;
#endif

	switch (com) {
#ifndef __riscos
	case FIONBIO:
		if ((tmp = *(int *)data))
			fp->f_flag |= FNONBLOCK;
		else
			fp->f_flag &= ~FNONBLOCK;
		error = (*fp->f_ops->fo_ioctl)(fp, FIONBIO, (caddr_t)&tmp, p);
		break;

	case FIOASYNC:
		if ((tmp = *(int *)data))
			fp->f_flag |= FASYNC;
		else
			fp->f_flag &= ~FASYNC;
		error = (*fp->f_ops->fo_ioctl)(fp, FIOASYNC, (caddr_t)&tmp, p);
		break;

	case FIOSETOWN:
		tmp = *(int *)data;
		if (fp->f_type == DTYPE_SOCKET) {
			((struct socket *)fp->f_data)->so_pgid = tmp;
			error = 0;
			break;
		}
		if (tmp <= 0) {
			tmp = -tmp;
		} else {
			struct proc *p1 = pfind(tmp);
			if (p1 == 0) {
				error = ESRCH;
				break;
			}
			tmp = p1->p_pgrp->pg_id;
		}
		error = (*fp->f_ops->fo_ioctl)
			(fp, (int)TIOCSPGRP, (caddr_t)&tmp, p);
		break;

	case FIOGETOWN:
		if (fp->f_type == DTYPE_SOCKET) {
			error = 0;
			*(int *)data = ((struct socket *)fp->f_data)->so_pgid;
			break;
		}
		error = (*fp->f_ops->fo_ioctl)(fp, (int)TIOCGPGRP, data, p);
		*(int *)data = -*(int *)data;
		break;
#endif
	default:
#ifdef __riscos
		error = soo_ioctl(so, com, data);
#else
		error = (*fp->f_ops->fo_ioctl)(fp, com, data, p);
#endif
		/*
		 * Copy any data to user, size was
		 * already set and checked above.
		 */
		if (error == 0 && (com&IOC_OUT) && size)
			error = copyout(data, uap->data, (u_int)size);
		break;
	}
#ifdef COMPAT_IBCS2
	if ((*(int *)(data - IBCS2_RETVAL_SIZE)) == IBCS2_MAGIC_OUT) {
		retval[0] = *(int *)(data-(IBCS2_RETVAL_SIZE - sizeof(int)));
		retval[1] = *(int *)(data-(IBCS2_RETVAL_SIZE - 2*sizeof(int)));
	}
#endif
	if (memp)
		free(memp, M_IOCTLOPS);
	return (error);
}

/*
 * Read system call.
 */
struct read_args {
	int	fd;
	char	*buf;
	u_int	nbyte;
};
/* ARGSUSED */
int
socketread(uap, retval)
	register struct read_args *uap;
	int *retval;
{
	struct uio auio;
	struct iovec aiov;
	struct socket *so;
    	long cnt, error = 0;

	if ((so = getsock(uap->fd)) == 0)
		return (EBADF);

        aiov.iov_base = (caddr_t)uap->buf;
	aiov.iov_len = uap->nbyte;
	auio.uio_iov = &aiov;
	auio.uio_iovcnt = 1;

	auio.uio_resid = uap->nbyte;
	if (auio.uio_resid < 0)
		return (EINVAL);

	auio.uio_rw = UIO_READ;
	auio.uio_segflg = UIO_USERSPACE;
#ifdef KTRACE
	/*
	 * if tracing, save a copy of iovec
	 */
	if (KTRPOINT(p, KTR_GENIO))
		ktriov = aiov;
#endif
	cnt = uap->nbyte;
	if ((error = soreceive(so, (struct mbuf **)0, &auio,
	       (struct mbuf **)0, (struct mbuf **)0, (int *)0)))
		if (auio.uio_resid != cnt && (error == ERESTART ||
		    error == EINTR || error == EWOULDBLOCK))
			error = 0;
	cnt -= auio.uio_resid;
#ifdef KTRACE
	if (KTRPOINT(p, KTR_GENIO) && error == 0)
		ktrgenio(p->p_tracep, uap->fd, UIO_READ, &ktriov, cnt, error);
#endif
	*retval = cnt;
	return (error);
}

/*
 * Scatter read system call.
 */
struct readv_args {
	int	fdes;
	struct	iovec *iovp;
	u_int	iovcnt;
};
int
socketreadv(uap, retval)
	register struct readv_args *uap;
	int *retval;
{
	struct uio auio;
	register struct iovec *iov;
	struct iovec *needfree;
	struct iovec aiov[UIO_SMALLIOV];
	struct socket *so;
	long i, cnt, error = 0;
	u_int iovlen;
#ifdef KTRACE
	struct iovec *ktriov = NULL;
#endif

    	if ((so = getsock(uap->fdes)) == 0)
		return (EBADF);
	/* note: can't use iovlen until iovcnt is validated */
	iovlen = uap->iovcnt * sizeof (struct iovec);
	if (uap->iovcnt > UIO_SMALLIOV) {
		if (uap->iovcnt > UIO_MAXIOV)
			return (EINVAL);
		MALLOC(iov, struct iovec *, iovlen, M_IOV, M_WAITOK);
		if (iov == NULL)
			return (ENOBUFS);
		needfree = iov;
	} else {
		iov = aiov;
		needfree = NULL;
	}
	auio.uio_iov = iov;
	auio.uio_iovcnt = uap->iovcnt;
	auio.uio_rw = UIO_READ;
	auio.uio_segflg = UIO_USERSPACE;
	if ((error = copyin((caddr_t)uap->iovp, (caddr_t)iov, iovlen)))
		goto done;
	auio.uio_resid = 0;
	for (i = 0; i < uap->iovcnt; i++) {
		auio.uio_resid += iov->iov_len;
		if (auio.uio_resid < 0) {
			error = EINVAL;
			goto done;
		}
		iov++;
	}
#ifdef KTRACE
	/*
	 * if tracing, save a copy of iovec
	 */
	if (KTRPOINT(p, KTR_GENIO))  {
		MALLOC(ktriov, struct iovec *, iovlen, M_TEMP, M_WAITOK);
		bcopy((caddr_t)auio.uio_iov, (caddr_t)ktriov, iovlen);
	}
#endif
	cnt = auio.uio_resid;
	if ((error = soreceive(so, (struct mbuf **)0, &auio,
	     (struct mbuf **)0, (struct mbuf **)0, (int *)0)))
		if (auio.uio_resid != cnt && (error == ERESTART ||
		    error == EINTR || error == EWOULDBLOCK))
			error = 0;
	cnt -= auio.uio_resid;
#ifdef KTRACE
	if (ktriov != NULL) {
		if (error == 0)
			ktrgenio(p->p_tracep, uap->fdes, UIO_READ, ktriov,
			    cnt, error);
		FREE(ktriov, M_TEMP);
	}
#endif
	*retval = cnt;
done:
	if (needfree)
		FREE(needfree, M_IOV);
	return (error);
}

/*
 * Write system call
 */
struct write_args {
	int	fd;
	char	*buf;
	u_int	nbyte;
};
int
socketwrite(uap, retval)
	register struct write_args *uap;
	int *retval;
{
#ifdef __riscos
	register struct socket *so;
#else
	register struct file *fp;
	register struct filedesc *fdp = p->p_fd;
#endif
	struct uio auio;
	struct iovec aiov;
	long cnt, error = 0;
#ifdef KTRACE
	struct iovec ktriov;
#endif

#ifdef __riscos
	if ((so = getsock(uap->fd)) == 0)
		return (EBADF);
#else
	if (((u_int)uap->fd) >= fdp->fd_nfiles ||
	    (fp = fdp->fd_ofiles[uap->fd]) == NULL ||
	    (fp->f_flag & FWRITE) == 0)
		return (EBADF);
#endif
	aiov.iov_base = (caddr_t)uap->buf;
	aiov.iov_len = uap->nbyte;
	auio.uio_iov = &aiov;
	auio.uio_iovcnt = 1;
	auio.uio_resid = uap->nbyte;
	auio.uio_rw = UIO_WRITE;
	auio.uio_segflg = UIO_USERSPACE;
#ifdef KTRACE
	/*
	 * if tracing, save a copy of iovec
	 */
	if (KTRPOINT(p, KTR_GENIO))
		ktriov = aiov;
#endif
	cnt = uap->nbyte;
#ifdef __riscos
	if ((error = sosend(so, 0, &auio, 0, 0, 0))) {
#else
	if ((error = (*fp->f_ops->fo_write)(fp, &auio, fp->f_cred))) {
#endif
		if (auio.uio_resid != cnt && (error == ERESTART ||
		    error == EINTR || error == EWOULDBLOCK))
			error = 0;
		if (error == EPIPE)
#ifdef __riscos
			psignal(pfind(so->so_pgid), SIGPIPE);
#else
			psignal(p, SIGPIPE);
#endif
	}
	cnt -= auio.uio_resid;
#ifdef KTRACE
	if (KTRPOINT(p, KTR_GENIO) && error == 0)
		ktrgenio(p->p_tracep, uap->fd, UIO_WRITE,
		    &ktriov, cnt, error);
#endif
	*retval = cnt;
	return (error);
}

/*
 * Gather write system call
 */
struct writev_args {
	int	fd;
	struct	iovec *iovp;
	u_int	iovcnt;
};
int
socketwritev(uap, retval)
	register struct writev_args *uap;
	int *retval;
{
	register struct socket *so;
	struct uio auio;
	register struct iovec *iov;
	struct iovec *needfree;
	struct iovec aiov[UIO_SMALLIOV];
	long i, cnt, error = 0;
	u_int iovlen;
#ifdef KTRACE
	struct iovec *ktriov = NULL;
#endif

	if ((so = getsock(uap->fd)) == 0)
		return (EBADF);
	/* note: can't use iovlen until iovcnt is validated */
	iovlen = uap->iovcnt * sizeof (struct iovec);
	if (uap->iovcnt > UIO_SMALLIOV) {
		if (uap->iovcnt > UIO_MAXIOV)
			return (EINVAL);
		MALLOC(iov, struct iovec *, iovlen, M_IOV, M_WAITOK);
		if (iov == NULL)
			return (ENOBUFS);
		needfree = iov;
	} else {
		iov = aiov;
		needfree = NULL;
	}
	auio.uio_iov = iov;
	auio.uio_iovcnt = uap->iovcnt;
	auio.uio_rw = UIO_WRITE;
	auio.uio_segflg = UIO_USERSPACE;
	if ((error = copyin((caddr_t)uap->iovp, (caddr_t)iov, iovlen)))
		goto done;
	auio.uio_resid = 0;
	for (i = 0; i < uap->iovcnt; i++) {
		auio.uio_resid += iov->iov_len;
		if (auio.uio_resid < 0) {
			error = EINVAL;
			goto done;
		}
		iov++;
	}
#ifdef KTRACE
	/*
	 * if tracing, save a copy of iovec
	 */
	if (KTRPOINT(p, KTR_GENIO))  {
		MALLOC(ktriov, struct iovec *, iovlen, M_TEMP, M_WAITOK);
		bcopy((caddr_t)auio.uio_iov, (caddr_t)ktriov, iovlen);
	}
#endif
	cnt = auio.uio_resid;
	if ((error = sosend(so, 0, &auio, 0, 0, 0))) {
		if (auio.uio_resid != cnt && (error == ERESTART ||
		    error == EINTR || error == EWOULDBLOCK))
			error = 0;
		if (error == EPIPE)
			psignal(pfind(so->so_pgid), SIGPIPE);
	}
	cnt -= auio.uio_resid;
#ifdef KTRACE
	if (ktriov != NULL) {
		if (error == 0)
			ktrgenio(p->p_tracep, uap->fd, UIO_WRITE,
				ktriov, cnt, error);
		FREE(ktriov, M_TEMP);
	}
#endif
	*retval = cnt;
done:
	if (needfree)
		FREE(needfree, M_IOV);
	return (error);
}

int
socketstat(int *r)
{
    struct a
    {
	int s;
	struct stat *ub;
    } *up = (struct a *)r;
    struct socket *so;

	if ((so = getsock(up->s)) == 0)
		return (EBADF);

	bzero((caddr_t)(up->ub), sizeof (*(up->ub)));
	up->ub->st_mode = S_IFSOCK;
	return ((*so->so_proto->pr_usrreq)(so, PRU_SENSE,
				       (struct mbuf *)(up->ub),
				       (struct mbuf *)0,
				       (struct mbuf *)0));
}

/*ARGSUSED*/
int
getstablesize(int *r, int *rval)
{
    *rval = SOCKTABSIZE;
    return (0);
}

int	selwait, nselcoll;

/*
 * Select system call.
 */
struct select_args {
	u_int	nd;
	fd_set	*in, *ou, *ex;
	struct	timeval *tv;
};
int
socketselect(uap, retval)
	register struct select_args *uap;
	int *retval;
{
	fd_set ibits[3], obits[3];
	struct timeval atv;
	int s, ncoll, error = 0, timo;
	u_int ni;
	int noblock = 0;

	bzero((caddr_t)ibits, sizeof(ibits));
	bzero((caddr_t)obits, sizeof(obits));

	if (uap->nd > SOCKTABSIZE)
		uap->nd = SOCKTABSIZE;	/* forgiving; slightly wrong */
	ni = howmany(uap->nd, NFDBITS) * sizeof(fd_mask);

#define	getbits(name, x) \
	if (uap->name && \
	    (error = copyin((caddr_t)uap->name, (caddr_t)&ibits[x], ni))) \
		goto done;
	getbits(in, 0);
	getbits(ou, 1);
	getbits(ex, 2);
#undef	getbits

	if (uap->tv) {
		error = copyin((caddr_t)uap->tv, (caddr_t)&atv,
			sizeof (atv));
		if (error)
			goto done;
		if (itimerfix(&atv)) {
			error = EINVAL;
			goto done;
		}
		s = splhi();
		timevaladd(&atv, (struct timeval *)&time);
#ifdef DEBUG
		if (DODEBUG(DBGSELECT))
			Printf("atv=(%d,%d), time=(%d,%d)\n",
			            atv.tv_sec, atv.tv_usec,
			            time.tv_sec, time.tv_usec);
#endif
		timo = hzto(&atv);
		/*
		 * Avoid inadvertently sleeping forever.
		 */
		if (timo == 0)
			timo = 1;
		splx(s);
	} else
		timo = 0;

#ifdef DEBUG
	if (DODEBUG(DBGSELECT))
		Printf("\nSelect timeout = %d\n", timo);
#endif
retry:
	ncoll = nselcoll;
    	error = selscan(ibits, obits, uap->nd, retval, &noblock);
    	if (error || *retval)
		goto done;
	s = splhi();
	/* this should be timercmp(&time, &atv, >=) */
	if (uap->tv && (time.tv_sec > atv.tv_sec ||
	    (time.tv_sec == atv.tv_sec && time.tv_usec >= atv.tv_usec))) {
#ifdef DEBUG
		if (DODEBUG(DBGSELECT)) {
			Printf("Time too late ");
			Printf("atv=(%d,%d), time=(%d,%d)\n",
			       atv.tv_sec, atv.tv_usec,
			       time.tv_sec, time.tv_usec);
		}
#endif
		splx(s);
		goto done;
	}
	if (nselcoll != ncoll) {
#ifdef DEBUG
		if (DODEBUG(DBGSELECT))
			Printf("Select has happened ");
#endif
		splx(s);
		goto retry;
	}
#ifdef DEBUG
	if (DODEBUG(DBGSELECT))
		Printf("sleeping ");
#endif
	error = tsleep((caddr_t)&selwait, PSOCK | PCATCH, "select", timo, noblock);
#ifdef DEBUG
	if (DODEBUG(DBGSELECT))
		Printf("woken ");
#endif
	splx(s);
	if (error == 0)
		goto retry;
done:
	/* select is not restarted after signals... */
	if (error == ERESTART)
		error = EINTR;
	if (error == EWOULDBLOCK)
		error = 0;
#define	putbits(name, x) \
	if (uap->name && \
	    (error2 = copyout((caddr_t)&obits[x], (caddr_t)uap->name, ni))) \
		error = error2;
	if (error == 0) {
		int error2;

		putbits(in, 0);
		putbits(ou, 1);
		putbits(ex, 2);
#undef putbits
	}

    return (error);
}

static int
selscan(ibits, obits, nfd, retval, noblock)
	fd_set *ibits, *obits;
	int nfd, *retval, *noblock;
{
    int msk, i, j, s;
    fd_mask bits;
    struct socket *so;
    int n = 0;
    static int flag[3] = { FREAD, FWRITE, 0 };

    for (msk = 0; msk < 3; msk++) {
	for (i = 0; i < nfd; i += NFDBITS) {
	    bits = ibits[msk].fds_bits[i/NFDBITS];
	    while ((j = ffs(bits)) && (s = i + --j) < nfd) {
		bits &= ~(1 << j);
		so = getsock(s);
		if (so == NULL)
		    return (EBADF);
		*noblock=so->so_state & SS_SLEEPTW;
		if (do_sock_select(so, flag[msk])) {
		    FD_SET(s, &obits[msk]);
		    n++;
		}
	    }
	}
    }
    *retval = n;
    return (0);
}

/*ARGSUSED*/
#if 0
static int seltrue(int dev, int flag)
{
    return (1);
}
#endif /* 0/1 */

/*
 * Record a select request.
 */
void
selrecord(selector, sip)
	struct proc *selector;
	struct selinfo *sip;
{
#ifdef __riscos
	sip->si_flags |= SI_COLL;
#else
	struct proc *p;
	pid_t mypid;

	mypid = selector->p_pid;
	if (sip->si_pid == mypid)
		return;
	if (sip->si_pid && (p = pfind(sip->si_pid)))
		sip->si_flags |= SI_COLL;
	else
		sip->si_pid = mypid;
#endif
}

/*
 * Do a wakeup when a selectable event occurs.
 */
void
selwakeup(sip)
	register struct selinfo *sip;
{
#ifdef DEBUG
	if (DODEBUG(DBGSELECT))
       		Printf("selwakeup(%x)\n", sip);
#endif
	if (sip->si_flags & SI_COLL) {
#ifdef DEBUG
		if (DODEBUG(DBGSELECT))
                	Printf("  Waking up!\n");
#endif
		nselcoll++;
		sip->si_flags &= ~SI_COLL;
		wakeup((caddr_t)&selwait);
	}
}

static int
do_sock_select(so, which)
	struct socket *so;
	int which;
{
	struct proc *p=pfind(so->so_pgid);

	switch (which) {

	case FREAD:
		if (soreadable(so))
			return (1);
		selrecord(p, &so->so_rcv.sb_sel);
		so->so_rcv.sb_flags |= SB_SEL;
		break;

	case FWRITE:
		if (sowriteable(so))
			return (1);
		selrecord(p, &so->so_snd.sb_sel);
		so->so_snd.sb_flags |= SB_SEL;
		break;

	case 0:
		if (so->so_oobmark || (so->so_state & SS_RCVATMARK))
			return (1);
		selrecord(p, &so->so_rcv.sb_sel);
		so->so_rcv.sb_flags |= SB_SEL;
		break;
	}
	return (0);
}

struct socket *
getsock(s)
	int s;
{
	if (s < 0 || s >= SOCKTABSIZE)
		return ((struct socket *)0);

    	return (socktab[s]);
}

int getsockid(struct socket *so)
{
    int sockid;

    for (sockid = 0; sockid < SOCKTABSIZE; sockid++)
	if (socktab[sockid] == so)
	    return (sockid);

    return (-1);
}

static int getsockslot(void)
{
    int sockid;

    for (sockid = 0; sockid < SOCKTABSIZE; sockid++)
	if (socktab[sockid] == 0)
	    return (sockid);

    return (-1);
}

int sockstats(void)
{
    int i;
    int sockcnt = 0;

    for (i = 0; i < SOCKTABSIZE; i++)
	if (socktab[i] != 0)
	    sockcnt++;

    return (sockcnt);
}

/* EOF socket_swi.c */
