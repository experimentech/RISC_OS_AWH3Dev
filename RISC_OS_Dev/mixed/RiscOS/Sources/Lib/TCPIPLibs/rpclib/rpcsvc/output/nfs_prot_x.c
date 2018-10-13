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
#include <rpc/rpc.h>
#include "nfs_prot.h"


bool_t
xdr_nfsstat(xdrs, objp)
        XDR *xdrs;
        nfsstat *objp;
{
        if (!xdr_enum(xdrs, (enum_t *)objp)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_ftype(xdrs, objp)
        XDR *xdrs;
        ftype *objp;
{
        if (!xdr_enum(xdrs, (enum_t *)objp)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_nfs_fh(xdrs, objp)
        XDR *xdrs;
        nfs_fh *objp;
{
        if (!xdr_opaque(xdrs, objp->data, NFS_FHSIZE)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_nfstime(xdrs, objp)
        XDR *xdrs;
        nfstime *objp;
{
        if (!xdr_u_int(xdrs, &objp->seconds)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->useconds)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_fattr(xdrs, objp)
        XDR *xdrs;
        fattr *objp;
{
        if (!xdr_ftype(xdrs, &objp->type)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->mode)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->nlink)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->uid)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->gid)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->size)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->blocksize)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->rdev)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->blocks)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->fsid)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->fileid)) {
                return (FALSE);
        }
        if (!xdr_nfstime(xdrs, &objp->atime)) {
                return (FALSE);
        }
        if (!xdr_nfstime(xdrs, &objp->mtime)) {
                return (FALSE);
        }
        if (!xdr_nfstime(xdrs, &objp->ctime)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_sattr(xdrs, objp)
        XDR *xdrs;
        sattr *objp;
{
        if (!xdr_u_int(xdrs, &objp->mode)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->uid)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->gid)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->size)) {
                return (FALSE);
        }
        if (!xdr_nfstime(xdrs, &objp->atime)) {
                return (FALSE);
        }
        if (!xdr_nfstime(xdrs, &objp->mtime)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_filename(xdrs, objp)
        XDR *xdrs;
        filename *objp;
{
        if (!xdr_string(xdrs, objp, NFS_MAXNAMLEN)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_nfspath(xdrs, objp)
        XDR *xdrs;
        nfspath *objp;
{
        if (!xdr_string(xdrs, objp, NFS_MAXPATHLEN)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_attrstat(xdrs, objp)
        XDR *xdrs;
        attrstat *objp;
{
        if (!xdr_nfsstat(xdrs, &objp->status)) {
                return (FALSE);
        }
        switch (objp->status) {
        case NFS_OK:
                if (!xdr_fattr(xdrs, &objp->attrstat_u.attributes)) {
                        return (FALSE);
                }
                break;
        }
        return (TRUE);
}




bool_t
xdr_sattrargs(xdrs, objp)
        XDR *xdrs;
        sattrargs *objp;
{
        if (!xdr_nfs_fh(xdrs, &objp->file)) {
                return (FALSE);
        }
        if (!xdr_sattr(xdrs, &objp->attributes)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_diropargs(xdrs, objp)
        XDR *xdrs;
        diropargs *objp;
{
        if (!xdr_nfs_fh(xdrs, &objp->dir)) {
                return (FALSE);
        }
        if (!xdr_filename(xdrs, &objp->name)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_diropokres(xdrs, objp)
        XDR *xdrs;
        diropokres *objp;
{
        if (!xdr_nfs_fh(xdrs, &objp->file)) {
                return (FALSE);
        }
        if (!xdr_fattr(xdrs, &objp->attributes)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_diropres(xdrs, objp)
        XDR *xdrs;
        diropres *objp;
{
        if (!xdr_nfsstat(xdrs, &objp->status)) {
                return (FALSE);
        }
        switch (objp->status) {
        case NFS_OK:
                if (!xdr_diropokres(xdrs, &objp->diropres_u.diropres)) {
                        return (FALSE);
                }
                break;
        }
        return (TRUE);
}




bool_t
xdr_readlinkres(xdrs, objp)
        XDR *xdrs;
        readlinkres *objp;
{
        if (!xdr_nfsstat(xdrs, &objp->status)) {
                return (FALSE);
        }
        switch (objp->status) {
        case NFS_OK:
                if (!xdr_nfspath(xdrs, &objp->readlinkres_u.data)) {
                        return (FALSE);
                }
                break;
        }
        return (TRUE);
}




bool_t
xdr_readargs(xdrs, objp)
        XDR *xdrs;
        readargs *objp;
{
        if (!xdr_nfs_fh(xdrs, &objp->file)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->offset)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->count)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->totalcount)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_readokres(xdrs, objp)
        XDR *xdrs;
        readokres *objp;
{
        if (!xdr_fattr(xdrs, &objp->attributes)) {
                return (FALSE);
        }
        if (!xdr_bytes(xdrs, (char **)&objp->data.data_val, (u_int *)&objp->data.data_len, NFS_MAXDATA)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_readres(xdrs, objp)
        XDR *xdrs;
        readres *objp;
{
        if (!xdr_nfsstat(xdrs, &objp->status)) {
                return (FALSE);
        }
        switch (objp->status) {
        case NFS_OK:
                if (!xdr_readokres(xdrs, &objp->readres_u.reply)) {
                        return (FALSE);
                }
                break;
        }
        return (TRUE);
}




bool_t
xdr_writeargs(xdrs, objp)
        XDR *xdrs;
        writeargs *objp;
{
        if (!xdr_nfs_fh(xdrs, &objp->file)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->beginoffset)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->offset)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->totalcount)) {
                return (FALSE);
        }
        if (!xdr_bytes(xdrs, (char **)&objp->data.data_val, (u_int *)&objp->data.data_len, NFS_MAXDATA)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_createargs(xdrs, objp)
        XDR *xdrs;
        createargs *objp;
{
        if (!xdr_diropargs(xdrs, &objp->where)) {
                return (FALSE);
        }
        if (!xdr_sattr(xdrs, &objp->attributes)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_renameargs(xdrs, objp)
        XDR *xdrs;
        renameargs *objp;
{
        if (!xdr_diropargs(xdrs, &objp->from)) {
                return (FALSE);
        }
        if (!xdr_diropargs(xdrs, &objp->to)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_linkargs(xdrs, objp)
        XDR *xdrs;
        linkargs *objp;
{
        if (!xdr_nfs_fh(xdrs, &objp->from)) {
                return (FALSE);
        }
        if (!xdr_diropargs(xdrs, &objp->to)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_symlinkargs(xdrs, objp)
        XDR *xdrs;
        symlinkargs *objp;
{
        if (!xdr_diropargs(xdrs, &objp->from)) {
                return (FALSE);
        }
        if (!xdr_nfspath(xdrs, &objp->to)) {
                return (FALSE);
        }
        if (!xdr_sattr(xdrs, &objp->attributes)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_nfscookie(xdrs, objp)
        XDR *xdrs;
        nfscookie objp;
{
        if (!xdr_opaque(xdrs, objp, NFS_COOKIESIZE)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_readdirargs(xdrs, objp)
        XDR *xdrs;
        readdirargs *objp;
{
        if (!xdr_nfs_fh(xdrs, &objp->dir)) {
                return (FALSE);
        }
        if (!xdr_nfscookie(xdrs, objp->cookie)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->count)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_entry(xdrs, objp)
        XDR *xdrs;
        entry *objp;
{
        if (!xdr_u_int(xdrs, &objp->fileid)) {
                return (FALSE);
        }
        if (!xdr_filename(xdrs, &objp->name)) {
                return (FALSE);
        }
        if (!xdr_nfscookie(xdrs, objp->cookie)) {
                return (FALSE);
        }
        if (!xdr_pointer(xdrs, (char **)&objp->nextentry, sizeof(entry), xdr_entry)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_dirlist(xdrs, objp)
        XDR *xdrs;
        dirlist *objp;
{
lightweight_printf( "xdr_dirlist: doing an xdr_pointer\n" );
        if (!xdr_pointer(xdrs, (char **)&objp->entries, sizeof(entry), xdr_entry)) {
lightweight_printf( "xdr_dirlist: xdr_pointer failed\n" );
                return (FALSE);
        }
lightweight_printf( "xdr_dirlist: xdr_pointer worked, doing an xdr_bool\n" );
        if (!xdr_bool(xdrs, &objp->eof)) {
lightweight_printf( "xdr_dirlist: xdr_bool failed\n" );
                return (FALSE);
        }
lightweight_printf( "xdr_dirlist: xdr_bool worked\n" );
        return (TRUE);
}




bool_t
xdr_readdirres(xdrs, objp)
        XDR *xdrs;
        readdirres *objp;
{
lightweight_printf( "doing a xdr_nfsstat\n" );
        if (!xdr_nfsstat(xdrs, &objp->status)) {
                return (FALSE);
        }
lightweight_printf( "xdr_nfsstat finished ok\n" );
        switch (objp->status) {
        case NFS_OK:
lightweight_printf( "doing a xdr_dirlist\n" );
                if (!xdr_dirlist(xdrs, &objp->readdirres_u.reply)) {
lightweight_printf( "xdr_dirlist finished but failed\n" );
                        return (FALSE);
                }
lightweight_printf( "xdr_dirlist finished and succeeded\n" );
                break;
        }
        return (TRUE);
}




bool_t
xdr_statfsokres(xdrs, objp)
        XDR *xdrs;
        statfsokres *objp;
{
        if (!xdr_u_int(xdrs, &objp->tsize)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->bsize)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->blocks)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->bfree)) {
                return (FALSE);
        }
        if (!xdr_u_int(xdrs, &objp->bavail)) {
                return (FALSE);
        }
        return (TRUE);
}




bool_t
xdr_statfsres(xdrs, objp)
        XDR *xdrs;
        statfsres *objp;
{
        if (!xdr_nfsstat(xdrs, &objp->status)) {
                return (FALSE);
        }
        switch (objp->status) {
        case NFS_OK:
                if (!xdr_statfsokres(xdrs, &objp->statfsres_u.reply)) {
                        return (FALSE);
                }
                break;
        }
        return (TRUE);
}


