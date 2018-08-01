Summary: Log R Package Usage for an R Session
Name: vrwatch
Version: 1.0.1
Release: 1
License: Proprietary
Group: Applications/Math
SOURCE0 : %{name}_%{version}.tar.gz
URL: http://www.mango-solutions.com

%define vrwatchdir %{_libdir}/vrwatch/library

BuildRequires: R-core

%description
%{summary}

%prep
%setup -q -n %{name}

%install
rm -rf %{buildroot}
mkdir -p  %{buildroot}%{prefix}
export QA_SKIP_BUILD_ROOT=true
mkdir -p %{buildroot}%{vrwatchdir}
R CMD INSTALL -l %{buildroot}%{vrwatchdir} \
    ${RPM_SOURCE_DIR}/%{name}_%{version}.tar.gz

mkdir -p %{buildroot}%{_sysconfdir}/rsyslog.d
echo -e ":syslogtag, isequal, \"VRWATCH:\" /var/log/vrwatch.log\n& ~" \
    > %{buildroot}%{_sysconfdir}/rsyslog.d/23-vrwatch.conf

%files
%attr(-,root,root) %{vrwatchdir}
%config %{_sysconfdir}/rsyslog.d/23-vrwatch.conf

%clean
rm -rf %{buildroot}

%post
# Need to find R first. If it is in the PATH, we just use that version
R=$(which R 2>/dev/null)

# Otherwise we look for validr
if [ -z "$R" ]; then
    if [ ! -d /opt/mango/R ]; then
	echo "Could not find R on system"
	exit 1;
    fi
    rversions=$(ls /opt/mango/R)
    if [ -z "$rversions" ]; then
	echo "Could not find R on system"
	exit 2;
    fi
    for ver in $rversions; do
	if [ -x /opt/mango/R/${ver}/bin/R ]; then
	    R=/opt/mango/R/${ver}/bin/R
	    break
	fi
    done
fi

if [ -z "$R" ]; then
    echo "Could not find R on system"
    exit 3;
fi

# Need to add the VRWATCH loading code to the site R profile
# We use a separate file, actually, and load this file from
# the main profile. It is easier to remove it this way
rhome=$(${R} --slave -e 'cat(R.home())')
rprofile=$rhome/etc/Rprofile.site
if [ ! -e $rprofile ] || ! grep -q VRWATCH $rprofile; then
    cat >> $rprofile <<EOF || exit 4

## -- VRWATCH --------------------------------------------------
## This was added by the VRWATCH package
## It allows specifying startup commands
## in a more granular way.
local(suppressWarnings(suppressMessages(
  tryCatch(
    {
      confdir <- file.path(R.home(), "etc", "Rprofile.d")
      if (file.exists(confdir) && file.info(confdir)\$isdir) {
        files <- list.files(confdir, full.names = TRUE)
        for (f in files) source(f)
      }
    },
    error = function(e) invisible()
  )
)))
## -- VRWATCH --------------------------------------------------
EOF
fi
mkdir -p $rhome/etc/Rprofile.d || exit 4
cat >> $rhome/etc/Rprofile.d/23-vrwatch.R <<EOF || exit 4
tryCatch(
  suppressWarnings(suppressMessages(
    loadNamespace("vrwatch", lib.loc = "%{vrwatchdir}")
  )),
  error = function(e) invisible()
)
EOF

# Restart rsyslog to start logging to the new vrwatch log
service rsyslog restart

%postun
service rsyslog restart

%changelog
* Thu 14 Jun 2018 Mango Solutions <support@mango-solutions.com> 1.0.1
- First ValidR release
