Name:           perl-MR-Rest
Version:        %{__version}
Release:        %{__release}%{?dist}

Summary:        Framework for development of RESTful services
License:        GPL+ or Artistic
Group:          MAILRU

BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
BuildArch:      noarch
Requires:       uwsgi >= 2.0.7
Requires:       uwsgi-plugin-psgi >= 2.0.7
Requires:       uwsgi-plugin-coroae >= 2.0.7
Requires:       perl(Plack)
Requires:       perl(EV)
Requires:       perl(Coro)
Requires:       perl(AnyEvent)

%description
Framework for development of RESTful services. Built from revision %{__revision}.

%prep
%setup -n rest

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
%{__make} %{?_smp_mflags}

%install
%{__make} pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} ';'
find $RPM_BUILD_ROOT -depth -type d -exec rmdir {} 2>/dev/null ';'
%{_fixperms} $RPM_BUILD_ROOT/*

%files
%defattr(-,root,root,-)
%{perl_vendorlib}/*

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%changelog
* Thu Nov 20 2014 Aleksey Mashanov <a.mashanov@corp.mail.ru>
- initial version

