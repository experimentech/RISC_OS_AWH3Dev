/* 
 * Copyright Julian Smith.
 * 
 * This file is part of Trace.
 * 
 * Trace is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 * 
 * Trace is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General
 * Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with Trace.  If not, see <http://www.gnu.org/licenses/>.
 */
#ifndef __APCSCheck_Defs_h
#define __APCSCheck_Defs_h


typedef struct	{
	int	r[16];
	}
	swi_regs;

void	Trace_APCSCheck_Start2( const char* fnname, swi_regs* r);
void	Trace_APCSCheck_Stop2( const char* fnname, swi_regs* r);

#endif
