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
#pragma force_top_level
#pragma include_only_once

/* fenv.h: ISO 'C' (9899:1999) library header, section 7.6 */
/* Copyright (C) Acorn Computers Ltd. 2002 */
/* version 1.01 */

#ifndef __fenv_h
#define __fenv_h

/*
 * The header <fenv.h> declares two types and several macros and functions
 * to provide access to the floating-point environment. The floating-point
 * environment refers to any floating-point status flags and contral modes
 * supported by the implementation. A floating-point status flag is a
 * system variable whose value is set (but never cleared) when a floating-
 * point exception is raised, which occurs as a side effect of exceptional
 * floating-point arithmetic to provide auxiliary information. A floating-
 * point control mode is a system variable whose value may be set by the
 * user to affect the subsequent behaviour of floating-point arithmetic.
 *
 * Certain programming conventions support the intended model of use for
 * the programming environment:
 *
 *   - a function call does not alter its caller's floating-point control
 *     modes, clear its caller's floating-point status flags, nor depend
 *     on the state of its caller's floating-point status flags unless the
 *     function is so documented;
 *   - a function call is assumed to require default floating-point control
 *     modes, unless its documentation promises otherwise;
 *   - a function call is assumed to have the potential for raising
 *     floating-point exceptions, unless its documentation promises
 *     otherwise.
 */

typedef struct __fenv_t_struct
{ unsigned __status;
  unsigned __reserved[5];
} fenv_t;
  /* represents the entire floating-point environment */

typedef unsigned int fexcept_t;
  /* represents the floating-point status flags collectively */

#define FE_INVALID    0x01
#define FE_DIVBYZERO  0x02
#define FE_OVERFLOW   0x04
#define FE_UNDERFLOW  0x08
#define FE_INEXACT    0x10
#define FE_ALL_EXCEPT 0x1F
  /* represent floating-point exceptions */

#define FE_TONEAREST 0
  /* our only supported rounding direction */

#define FE_DFL_ENV ((const fenv_t *) 0)
  /* represents the default floating-point environment - the one installed */
  /* at program startup. It can be used as an argument to <fenv.h> */
  /* functions that manage the floating point environment. */

/* #pragma STDC FENV_ACCESS ON|OFF|DEFAULT */
  /* The FENV_ACCESS pragma provides a means to inform the implementation */
  /* when a program might access the floating-point environment to test */
  /* floating-point status flags or run under non-default floating-point */
  /* control modes. The pragma shall occur either outside external */
  /* declarations or preceding all explicit declarations and statements */
  /* inside a compound statement. When outside external declarations, the */
  /* pragma takes effect from its occurrence until another FENV_ACCESS */
  /* pragma is encountered, or until the end of the translation unit. When */
  /* inside a compound statement, the pragma takes effect from its */
  /* occurrence until another FENV_ACCESS pragma is encountered (including */
  /* within a nested compound statement), or until the end of the compound */
  /* statement; at the end of a compound statement the state for the */
  /* pragma is restored to its condition just before the compound */
  /* statement. If this pragma is used in any other context, the behaviour */
  /* is undefined. If part of a program tests floating-point status flags, */
  /* sets floating-point control modes, or runs under non-default mode */
  /* settings, but was translated with the state for the FENV_ACCESS */
  /* pragma "off", the behaviour is undefined. The default state ("on" or */
  /* "off") for the pragma is implementation-defined ("off" in  */
  /* Norcroft C). (When execution passes from a part of the program */
  /* translated with FENV_ACCESS "off" to a part translated with */
  /* FENV_ACCESS "on", the state of the floating-point status flags is */
  /* unspecified and the floatng-point control modes have their default */
  /* settings.) */

#ifdef __cplusplus
extern "C" {
#endif
int feclearexcept(int /*excepts*/);
  /* attempts to clear the supported floating-point exceptions represented */
  /* by its argument. */
  /* Returns: zero if the excepts argument is zero or if all the specified */
  /*          exceptions were successfully cleared. Otherwise, it returns  */
  /*          a nonzero value. */
int fegetexceptflag(fexcept_t */*flagp*/, int /*excepts*/);
  /* attempts to store an implementation-defined representation of the */
  /* states of the floating-point status flags indicated by the argument */
  /* excepts in the object pointed to by the argument flagp. */
  /* Returns: zero if the representation was successfully stored. */
  /*          Otherwise, it returns a nonzero value. */
int feraiseexcept(int /*excepts*/);
  /* attempts to raise the supported floating-point exceptions represented */
  /* by its argument. The order in which these floating-point exceptions */
  /* are raised is unspecified, except as stated in F.7.6. Whether the */
  /* feraiseexcept function additionally raises the "inexact" floating- */
  /* point exception whenever it raises the "overflow" or "underflow" */
  /* floating-point exception is implementation-defined. */
  /* Returns: zero if the excepts argument is zero or if all the specified */
  /*          exceptions were successfully raised. Otherwise, it returns a */
  /*          nonzero value. */
int fesetexceptflag(const fexcept_t */*flagp*/, int /*excepts*/);
  /* attempts to set the floating-point status flags indicated by the */
  /* argument excepts to the states stored in the object pointed to by */
  /* flagp. The value of *flagp shall have been set by a previous call to */
  /* fegetexceptflag whose second argument represented at least those */
  /* floating-point exceptions represented by the argument excepts. This */
  /* function does not raise floating-point exceptions, but only sets the */
  /* state of the flags. */
  /* Returns: zero if the excepts argument is zero or if all the specified */
  /*          flags were successfully set to the appropriate state. */
  /*          Otherwise, it returns a nonzero value. */
int fetestexcept(int /*excepts*/);
  /* determines which of a specified subset of the floating-point */
  /* exception flags are currently set. The excepts argument specifies the */
  /* floating-point status flags to be queried. */
  /* Returns: the value of the bitwise OR of the floating-point exception */
  /*          macros corresponding to the currently set floating-point */
  /*          exceptions included in excepts. */

int fegetround(void);
  /* gets the current rounding direction. */
  /* Returns: the value of the rounding direction macro representing the */
  /*          current rounding direction or a negative value if there is */
  /*          no such rounding direction macro or the current rounding */
  /*          direction is not determinable. */
int fesetround(int /*round*/);
  /* establishes the rounding direction represented by its argument round. */
  /* If the argument is not equal to the value of a rounding direction */
  /* macro, the rounding direction is not changed. */
  /* Returns: zero if and only if the requested rounding direction was */
  /*          established. */

int fegetenv(fenv_t */*envp*/);
  /* attempts to store the current floating-point environment in the */
  /* object pointed to by envp. */
  /* Returns: zero if the environment was successfully stored. Otherwise, */
  /*          it returns a nonzero value. */
int feholdexcept(fenv_t */*envp*/);
  /* saves the current floating-point environment in the object pointed to */
  /* by envp, clears the floating-point status flags, and then installs a */
  /* non-stop (continue on floating-point exceptions) mode for all */
  /* floating-point exceptions. */
  /* Returns: zero if and only if non-stop floating-point exception */
  /*          handling was successfully installed. */
int fesetenv(const fenv_t */*envp*/);
  /* attempts to establish the floating-point environment represented by */
  /* the object pointed to by envp. The argument envp shall point to an */
  /* object set by a call to fegetenv or feholdexcept, or equal a */
  /* floating-point environment macro. Note that fesetenv merely installs */
  /* the state of the floating-point status flags represented through its */
  /* argument, and does not raise these floating-point exceptions. */
  /* Returns: zero if the environment was successfully established. */
  /*          Otherwise, it returns a nonzero value. */
int feupdateenv(const fenv_t */*envp*/);
  /* attempts to save the currently raised floating-point exceptions in */
  /* its automatic storage, install the floating-point environment */
  /* represented by the object pointed to by envp, and then raise the */
  /* saved floating-point exceptions. The argument envp shall point to an */
  /* object set by a call to feholdexcept or fegetenv, or equal a */
  /* floating-point environment macro. */
  /* Returns: zero if all the actions were successfully carried out. */
  /*          Otherwise, it returns a nonzero value. */

#ifdef __cplusplus
}
#endif

#endif

/* end of fenv.h */
