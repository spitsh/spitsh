#| The curl command. Referencing this ensures that curl is
#| installed.
#|{ say ${ $:curl -V } }
constant Cmd $:curl = on {
    Spit-Helper { 'curl' }
    RHEL { 'curl' }
    Debian {
        Pkg<ca-certificates>.ensure-install;
        Cmd<curl>.ensure-install;
    }
    Alpine { Cmd<curl>.ensure-install }
}

constant Cmd $:wget = on {
    Any { Cmd<wget>.ensure-install }
    Alpine {
        Pkg<wget openssl ca-certificates>.install;
        'wget'
    }
}

constant Cmd $:gcc-make = on {
    Debian { Pkg<gcc make libc-dev>.install; 'make' }
    RHEL   { Pkg<gcc make glibc-devel>.install; 'make' }
    Alpine { Pkg<gcc make libc-dev>.install;    'make' }
}

constant $:jq-repo = GitHub<stedolan/jq>;

my HTTP $?jq-download-url  = 'https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux32-no-oniguruma';
my $?jq-sha256sum = '264118228c08abf4db8d9e907b9638914f3eadb5cd50dc1471a84463f7991be0';

constant Cmd $:jq = on {
    Linux {
        Cmd<jq> or (
            given $?jq-download-url.get-file(to => File.tmp) {
                .sha256-ok($?jq-sha256sum, what => $?jq-download-url);
                .chmod('u+x');
                $_;
            }
        )
    }
    Spit-Helper { 'jq' }
}

constant Cmd $:socat = on {
    Any { Cmd<socat>.ensure-install }
    Spit-Helper { 'socat' }
}

constant Cmd $:ss = on {
    Debian { 'ss' }
}

constant Cmd $:netstat = on {
    RHEL { Pkg<net-tools>.ensure-install; 'netstat' }
    Alpine { 'netstat' }
}

constant Pkg $:Pkg-ssl = on {
    Alpine { 'libressl' }
    Debian { 'openssl'  }
    RHEL   { 'openssl'  }
}

constant Cmd $:ssl = {
    $:Pkg-ssl.ensure-install;
    'openssl'
}

constant Cmd $:gpg = Cmd<gpg>.ensure-install;

constant $:tcpdump = Cmd<tcpdump>.ensure-install;

constant $:perl = on {
    Debian { 'perl' }
    Any    { Cmd<perl>.ensure-install }
}
