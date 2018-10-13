# 
# Copyright (c) 2012, RISC OS Open Ltd
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of RISC OS Open Ltd nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# 

#
# Program specific options:
#
COMPONENT  = SDCreate
APP        = !${COMPONENT}
RDIR       = Resources
LDIR       = ${RDIR}.${LOCALE}

include StdTools

FILES  =\
 $(LDIR).!Boot\
 $(LDIR).!Run\
 $(LDIR).!Help\
 $(RDIR).SDCreate\
 $(LDIR).!Sprites\
 $(LDIR).!Sprites22\
 $(RDIR).Desc\
 $(LDIR).Templates\
 $(RDIR).blank\
 $(RDIR).blankwand\
 $(RDIR).scripts.BeagleBoard\
 $(RDIR).scripts.DevKit8000\
 $(RDIR).scripts.IGEPv2\
 $(RDIR).scripts.PandaBoard\
 $(RDIR).scripts.Pandora\
 $(RDIR).scripts.uenv\
 $(RDIR).scripts.source.beagle\
 $(RDIR).scripts.source.convert\
 $(RDIR).scripts.source.devkit\
 $(RDIR).scripts.source.igep\
 $(RDIR).scripts.source.panda\
 $(RDIR).scripts.source.pandora\
 $(LDIR).Messages

#
# Generic build rules:
#
all: $(FILES)
     @echo $(COMPONENT): all build complete

install release_autobuild: $(FILES)
         ${MKDIR} ${INSTDIR}.${APP}.scripts.source
         |
         ${CP} $(LDIR).!Boot       ${INSTDIR}.${APP}.!Boot      ${CPFLAGS}
         ${CP} $(LDIR).!Run        ${INSTDIR}.${APP}.!Run       ${CPFLAGS}
         ${CP} $(LDIR).!Help       ${INSTDIR}.${APP}.!Help      ${CPFLAGS}
         ${CP} $(RDIR).SDCreate    ${INSTDIR}.${APP}.SDCreate   ${CPFLAGS}
         ${CP} $(LDIR).!Sprites    ${INSTDIR}.${APP}.!Sprites   ${CPFLAGS}
         ${CP} $(LDIR).!Sprites22  ${INSTDIR}.${APP}.!Sprites22 ${CPFLAGS}
         ${CP} $(RDIR).Desc        ${INSTDIR}.${APP}.Desc       ${CPFLAGS}
         ${CP} $(LDIR).Templates   ${INSTDIR}.${APP}.Templates  ${CPFLAGS}
         ${CP} $(RDIR).blank       ${INSTDIR}.${APP}.blank      ${CPFLAGS}
         ${CP} $(RDIR).blankwand   ${INSTDIR}.${APP}.blankwand  ${CPFLAGS}
         ${CP} $(LDIR).Messages    ${INSTDIR}.${APP}.Messages   ${CPFLAGS}
         |
         ${CP} $(RDIR).scripts.BeagleBoard          ${INSTDIR}.${APP}.scripts.BeagleBoard/scr    ${CPFLAGS}
         ${CP} $(RDIR).scripts.DevKit8000           ${INSTDIR}.${APP}.scripts.DevKit8000/scr     ${CPFLAGS}
         ${CP} $(RDIR).scripts.IGEPv2               ${INSTDIR}.${APP}.scripts.IGEPv2/scr         ${CPFLAGS}
         ${CP} $(RDIR).scripts.PandaBoard           ${INSTDIR}.${APP}.scripts.PandaBoard/scr     ${CPFLAGS}
         ${CP} $(RDIR).scripts.Pandora              ${INSTDIR}.${APP}.scripts.Pandora/scr        ${CPFLAGS}
         ${CP} $(RDIR).scripts.uenv                 ${INSTDIR}.${APP}.scripts.uenv/txt           ${CPFLAGS}
         ${CP} $(RDIR).scripts.Wandboard            ${INSTDIR}.${APP}.scripts.Wandboard/txt      ${CPFLAGS}
         |
         ${CP} $(RDIR).scripts.source.beagle        ${INSTDIR}.${APP}.scripts.source.beagle      ${CPFLAGS}
         ${CP} $(RDIR).scripts.source.convert       ${INSTDIR}.${APP}.scripts.source.convert     ${CPFLAGS}
         ${CP} $(RDIR).scripts.source.devkit        ${INSTDIR}.${APP}.scripts.source.devkit      ${CPFLAGS}
         ${CP} $(RDIR).scripts.source.igep          ${INSTDIR}.${APP}.scripts.source.igep        ${CPFLAGS}
         ${CP} $(RDIR).scripts.source.panda         ${INSTDIR}.${APP}.scripts.source.panda       ${CPFLAGS}
         ${CP} $(RDIR).scripts.source.pandora       ${INSTDIR}.${APP}.scripts.source.pandora     ${CPFLAGS}
         |
         Access ${INSTDIR}.${APP} /r
         Access ${INSTDIR}.${APP}.* LR/r
         |
         @echo $(COMPONENT): installed

clean:
       $(RM) $(RDIR).SDCreate
       $(RM) $(RDIR).Desc
       ${XWIPE} crunched ${WFLAGS}
       @echo $(COMPONENT): cleaned

#
# Static dependencies:
#
                     
$(RDIR).SDCreate: crunched.SDCreate
        $(SQUISH) $(SQUISHFLAGS) -from crunched.SDCreate -to $@

crunched.SDCreate: bas.SDCreate
        ${MKDIR} crunched
        ${RUN}BasCrunch -1 bas.SDCreate $@

$(RDIR).Desc: $(LDIR).Desc
        ${AWK} -f Build:AwkVers descmode=1 < $(LDIR).Desc > $@

#---------------------------------------------------------------------------
# Dynamic dependencies:
