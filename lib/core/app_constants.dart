class AppConstants {
  AppConstants._();

  // App Metadata
  static const String appName = 'Snapgrove';
  static const String appTagline = 'Fast, distraction-free screenshot & image organizer';
  static const String appVersion = '01.07.41+34';
  static const String appVersionName = 'v1.7.41';
  static const String appBuildNumber = '34';

  // URLs & Links
  static const String repoUrl = 'https://github.com/SubhamSathua/snapgrove';
  static const String repoCloneUrl = 'https://github.com/SubhamSathua/snapgrove.git';
  static const String issuesUrl = 'https://github.com/SubhamSathua/snapgrove/issues';
  static const String releasesUrl = 'https://github.com/SubhamSathua/snapgrove/releases';
  static const String discussionsUrl = 'https://github.com/SubhamSathua/snapgrove/discussions';
  static const String authorName = 'Subham Sathua';
  static const String authorGithub = 'https://github.com/SubhamSathua';
  static const String licenseType = 'MIT License';
  static const String contactEmail = 'contact@snapgrove.app';

  // About Features & Highlights
  static const List<Map<String, String>> keyFeatures = [
    {
      'title': '100% Offline & Private',
      'description': 'Zero cloud sync, zero telemetry, and zero ads. Your screenshots never leave your local storage.',
      'icon': 'assets/icons/shield.svg',
    },
    {
      'title': 'Blazing SAF Performance',
      'description': 'Engineered with single-scan batching and asynchronous chunked pipelines for instantaneous multi-file moves.',
      'icon': 'assets/icons/folder-plus.svg',
    },
    {
      'title': 'Intelligent Preview Cache',
      'description': 'Adaptive 3-tier in-memory LRU cache with background bidirectional preloading for silky-smooth 60fps zooming.',
      'icon': 'assets/icons/preview.svg',
    },
    {
      'title': 'Cross-Platform Harmony',
      'description': 'Consistent design system with glassmorphism blur across Android, Windows, and modern Web platforms.',
      'icon': 'assets/icons/desktop.svg',
    },
  ];

  // Privacy Policy Clauses
  static const String privacyLastUpdated = 'October 2026';

  static const List<Map<String, dynamic>> privacySections = [
    {
      'title': '1. Core Philosophy: Offline-First',
      'content':
          'Snapgrove is built from the ground up as a strictly local-first application. We believe your screenshots, captures, and personal photos belong exclusively to you. Snapgrove does not collect, transmit, store, or sell any of your media or personal information to external servers.',
    },
    {
      'title': '2. Device Storage & Scoped Access',
      'content':
          'Snapgrove requires permission to read and manage selected folders solely to display, organize, move, and categorize your screenshots.\n\n• On Android: Snapgrove uses Google\'s Storage Access Framework (SAF) to request permission only for directories you explicitly select via the system document picker.\n• On Windows: File access is restricted strictly to folders you explicitly choose to browse or set as your permanent screenshot directory.\n• On Web: The browser File System Access API is used to access only handles you explicitly authorize during your session.',
    },
    {
      'title': '3. Telemetry, Tracking & Analytics',
      'content':
          'Snapgrove contains NO analytics SDKs, NO crash report aggregators, NO tracking cookies, and NO advertising identifiers. We do not track your usage habits, device identifiers, folder names, or file counts.',
    },
    {
      'title': '4. EXIF & Metadata Sanitization',
      'content':
          'Snapgrove includes client-side EXIF cleaning capabilities. When you choose to sanitize or share images, metadata scrubbing occurs entirely in local device memory before export. No metadata is ever sent over the network.',
    },
    {
      'title': '5. Open Source & Auditability',
      'content':
          'Snapgrove is open source under the MIT License. Anyone can inspect the complete source code, audit permissions, verify that no network telemetry exists, and compile their own builds directly from the GitHub repository.',
    },
    {
      'title': '6. Contact & Inquiries',
      'content':
          'If you have questions, feedback, or security concerns regarding this privacy policy or the application, you can reach out via GitHub Issues or by contacting the maintainer at https://github.com/SubhamSathua/snapgrove.',
    },
  ];

  // Curated Open Source Packages & Dependencies
  static const List<Map<String, String>> openSourcePackages = [
    {
      'name': 'fluentui-system-icons',
      'version': 'Assets / SVG',
      'license': 'MIT',
      'author': 'Microsoft Corporation',
      'description': 'Fluent System Icons collection for modern cross-platform design.',
      'url': 'https://github.com/microsoft/fluentui-system-icons',
      'text': '''MIT License

Copyright (c) Microsoft Corporation.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''',
    },
    {
      'name': 'flutter',
      'version': '3.x (SDK)',
      'license': 'BSD-3-Clause',
      'author': 'Flutter Authors',
      'description': 'Google\'s UI toolkit for building natively compiled applications.',
      'url': 'https://github.com/flutter/flutter',
      'text': '''Copyright 2014 The Flutter Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of Google Inc. nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.''',
    },
    {
      'name': 'saf_util',
      'version': '^3.1.0',
      'license': 'Apache-2.0',
      'author': 'fluttervn',
      'description': 'Android Storage Access Framework (SAF) directory and file manipulation.',
      'url': 'https://pub.dev/packages/saf_util',
      'text': '''Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.''',
    },
    {
      'name': 'saf_stream',
      'version': '^3.0.0',
      'license': 'Apache-2.0',
      'author': 'fluttervn',
      'description': 'Streaming binary I/O support for Android SAF content URIs.',
      'url': 'https://pub.dev/packages/saf_stream',
      'text': '''Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.''',
    },
    {
      'name': 'flutter_svg',
      'version': '^2.3.0',
      'license': 'MIT',
      'author': 'Dan Field & Flutter Community',
      'description': 'SVG rendering and asset parsing widget for Flutter.',
      'url': 'https://pub.dev/packages/flutter_svg',
      'text': '''MIT License

Copyright (c) 2018 Dan Field

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''',
    },
    {
      'name': 'animations',
      'version': '^2.2.0',
      'license': 'BSD-3-Clause',
      'author': 'Flutter Authors',
      'description': 'High-performance Material animations including OpenContainer fade-through transitions.',
      'url': 'https://pub.dev/packages/animations',
      'text': '''Copyright 2019 The Flutter Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of Google Inc. nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.''',
    },
    {
      'name': 'get_it',
      'version': '^8.0.2',
      'license': 'MIT',
      'author': 'Thomas Burkhart',
      'description': 'Simple direct service locator for dependency injection.',
      'url': 'https://pub.dev/packages/get_it',
      'text': '''MIT License

Copyright (c) 2018 Thomas Burkhart

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.''',
    },
    {
      'name': 'url_launcher',
      'version': '^6.3.2',
      'license': 'BSD-3-Clause',
      'author': 'Flutter Authors',
      'description': 'Flutter plugin for launching URLs across mobile, desktop, and web.',
      'url': 'https://pub.dev/packages/url_launcher',
      'text': '''Copyright 2013 The Flutter Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of Google Inc. nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.''',
    },
    {
      'name': 'shared_preferences',
      'version': '^2.5.5',
      'license': 'BSD-3-Clause',
      'author': 'Flutter Authors',
      'description': 'Persistent key-value store for preferences and app settings.',
      'url': 'https://pub.dev/packages/shared_preferences',
      'text': '''Copyright 2013 The Flutter Authors. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.''',
    },
    {
      'name': 'file_selector',
      'version': '^1.1.0',
      'license': 'BSD-3-Clause',
      'author': 'Flutter Authors',
      'description': 'Desktop and Web native file & directory picker plugin.',
      'url': 'https://pub.dev/packages/file_selector',
      'text': '''Copyright 2013 The Flutter Authors. All rights reserved.''',
    },
    {
      'name': 'share_plus',
      'version': '^10.0.0',
      'license': 'BSD-3-Clause',
      'author': 'Flutter Community',
      'description': 'Cross-platform content and image sharing widget plugin.',
      'url': 'https://pub.dev/packages/share_plus',
      'text': '''Copyright 2019 The Chromium Authors. All rights reserved.
Copyright 2020 The Flutter Community Authors. All rights reserved.''',
    },
    {
      'name': 'idb_shim',
      'version': '^2.9.3',
      'license': 'MIT',
      'author': 'Alexandre Roux Tekartik',
      'description': 'IndexedDB wrapper and shim for Web local persistence.',
      'url': 'https://pub.dev/packages/idb_shim',
      'text': '''MIT License

Copyright (c) 2016 Alexandre Roux Tekartik''',
    },
    {
      'name': 'Material Symbols Rounded',
      'version': 'Variable Font',
      'license': 'Apache-2.0',
      'author': 'Google LLC',
      'description': 'Modern, consolidated icon symbol font from Google.',
      'url': 'https://github.com/google/material-design-icons',
      'text': '''Copyright Google LLC.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0''',
    },
    {
      'name': 'Lora Font',
      'version': 'Variable Font',
      'license': 'OFL-1.1',
      'author': 'Cyreal',
      'description': 'Contemporary serif typeface designed for text and digital typography.',
      'url': 'https://github.com/cyrealtype/Lora-Cyrillic',
      'text': '''Copyright 2011 The Lora Project Authors (https://github.com/cyrealtype/Lora-Cyrillic), with Reserved Font Name "Lora".
Licensed under the SIL Open Font License, Version 1.1.''',
    },
    {
      'name': 'JetBrains Mono Font',
      'version': 'Variable Font',
      'license': 'OFL-1.1',
      'author': 'JetBrains',
      'description': 'Free and open-source monospaced typeface crafted specifically for developers.',
      'url': 'https://github.com/JetBrains/JetBrainsMono',
      'text': '''Copyright 2020 The JetBrains Mono Project Authors (https://github.com/JetBrains/JetBrainsMono).
Licensed under the SIL Open Font License, Version 1.1.''',
    },
  ];
}
