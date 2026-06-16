# Third-party notices

MINT bundles and uses the following components.

## MediaInfo (CLI), libmediainfo, libzen

© MediaArea.net SARL. Licensed under the **BSD 2-Clause License**.

- https://mediaarea.net/MediaInfo
- https://github.com/MediaArea/MediaInfo
- https://github.com/MediaArea/MediaInfoLib
- https://github.com/MediaArea/ZenLib

The `mediainfo` command-line tool, `libmediainfo.0.dylib`, and `libzen.0.dylib`
(Homebrew builds, v26.05 / libzen 0.4.41) are bundled inside
`MINT.app/Contents/Resources/MediaInfoCLI/` with their library load paths
rewritten to `@loader_path` so the app is self-contained. The libraries are
unmodified.

```
BSD 2-Clause License

Copyright (c) MediaArea.net SARL. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
