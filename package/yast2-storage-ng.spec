#
# spec file for package yast2-storage-ng
#
# Copyright (c) 2019 SUSE LLC.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:		yast2-storage-ng
Version:	4.1.84
Release:	0

BuildRoot:	%{_tmppath}/%{name}-%{version}-build
Source:		%{name}-%{version}.tar.bz2

# CWM::Dialog#next_handler (4.1 branch) and improved CWM::Dialog
Requires:	yast2 >= 4.1.11
# for AbortException and handle direct abort
Requires:	yast2-ruby-bindings >= 4.0.6
# Bcache#remove_bcache_cset
Requires:	libstorage-ng-ruby >= 4.1.89
# communicate with udisks
Requires:	rubygem(ruby-dbus)
# Y2Packager::Repository
Requires:	yast2-packager >= 3.3.7
# findutils for xargs
Requires:	findutils

BuildRequires:	update-desktop-files
# Bcache#remove_bcache_cset
BuildRequires:	libstorage-ng-ruby >= 4.1.89
BuildRequires:	yast2-ruby-bindings
BuildRequires:	yast2-devtools
# yast2-xml dependency is added by yast2 but ignored in the
# openSUSE:Factory project config
BuildRequires:  yast2-xml
# CWM::Dialog#next_handler (4.1 branch) and improved CWM::Dialog
BuildRequires:	yast2 >= 4.1.11
# for AbortException and handle direct abort
BuildRequires:	yast2-ruby-bindings >= 4.0.6
BuildRequires:	rubygem(yast-rake)
BuildRequires:	rubygem(rspec)
# speed up the tests in SLE15-SP1+ or TW
%if 0%{?sle_version} >= 150100 || 0%{?suse_version} > 1500
BuildRequires:	rubygem(parallel_tests)
%endif
# communicate with udisks
BuildRequires:	rubygem(ruby-dbus)
PreReq:         %fillup_prereq

Obsoletes:	yast2-storage

Group:		System/YaST
License:	GPL-2.0-only or GPL-3.0-only
Summary:	YaST2 - Storage Configuration

%description
This package contains the files for YaST2 that handle access to disk
devices during installation and on an installed system.
This YaST2 module uses libstorage-ng.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%install
rake install DESTDIR="%{buildroot}"

# Remove the license from the /usr/share/doc/packages directory,
# it is also included in the /usr/share/licenses directory by using
# the %license tag.
rm -f $RPM_BUILD_ROOT/%{yast_docdir}/COPYING

%post
%ifarch s390 s390x
%{fillup_only -ans storage %{name}.s390}
%else
%{fillup_only -ans storage %{name}.default}
%endif

%files
%defattr(-,root,root)
%{yast_dir}/clients/*.rb
%{yast_dir}/lib
%{yast_desktopdir}/*.desktop
%{yast_fillupdir}/*
%{yast_ybindir}/*

# agents-scr
%{yast_scrconfdir}/*.scr

# icons
%{yast_icondir}

%license COPYING
%doc README.md
%doc CONTRIBUTING.md

%build
