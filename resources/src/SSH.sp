constant Pkg $:Pkg-openssh-client = on {
    Alpine { 'openssh-client'  }
    Debian { 'openssh-client'  }
    RHEL   { 'openssh-clients' }
}

constant Cmd $:sshd is logged-as("\c[BLOWFISH]") = {
    on {
        Alpine { Pkg<openssh>.ensure-install }
        Any    { Pkg<openssh-server>.ensure-install }
    }
    Cmd<sshd>.path;
}

constant Cmd $:ssh is logged-as("\c[BLOWFISH]") = on {
    Any {
        Cmd<ssh> or
        $:Pkg-openssh-client.install && 'ssh';
    }
    Spit-Helper { 'ssh' }
}

constant Cmd $:ssh-keygen = ($:ssh; 'ssh-keygen');
constant Cmd $:ssh-keyscan is logged-as("\c[BLOWFISH, KEY, RIGHT-POINTING MAGNIFYING GLASS]") = ($:ssh; 'ssh-keyscan');
constant $:ssh-known-hosts is export = $:HOME.add('.ssh').mkdir.add('known_hosts');
constant $:ssh-conf-dir = File</etc/ssh>;
constant $:authorized_keys is export = $:HOME.add('.ssh').mkdir.add('authorized_keys');

class SSH-known-host is Str is primitive { }

class SSH-public-key is Str is primitive {
    method keytype~ { $self.${awk '{print $1}'} }
    method type~ {
        given $self.keytype {
            when /^ecdsa-/   { 'ecdsa' }
            when /^ssh-rsa$/ { 'rsa' }
            when /^ssh-dss$/ { 'dsa' }
            when /^ssh-ed25519$/ { 'ed25519' }
        }
    }
    method key~  { $self.${awk '{print $2}'} }
    method comment~ { $self.${awk '{prnint $3}'} }
    method known-host($host) -->SSH-known-host {
        "$host $self"-->SSH-known-host
    }

    method fingerprint(:$algo)~ {
        $self.${
            $:ssh-keygen -lf- ("-E$_" if $algo) |
            awk '{sub(/[^:]+:/,"",$2); print $2}'
        }
    }
}

augment SSH-known-host  {
    method public-key -->SSH-public-key {
        $self.${cut '-d ' -f2-}
    }

    method host -->Host {
        $self.${awk '{print $1}'}
    }

    method add { $self-->List[SSH-known-host].add }
}

augment List[SSH-known-host] {
    method add { $:ssh-known-hosts.push: $self }
}

class SSH-keypair is File {
    constant $:type = 'ed25519';
    method private-key-file -->File { $self }
    method public-key-file -->File  { "$self.pub" }
    method type~                    { $self.public-key.type }
    method keytype~                 { $self.public-key.keytype }
    method remove?                  ${rm $self $self.public-key-file !>X}
    method exists?                  { $self.private-key-file and $self.public-key-file }
    method Bool                     { $self.exists }
    method private-key~             { $self.slurp }
    method public-key -->SSH-public-key { $self.public-key-file.slurp-->SSH-public-key }
    method generate-public-key {
        ${ $:ssh-keygen -yf $self >($self.public-key-file) !>error };
    }

    static method new(
        :$type = $:type,
        Int :$bits,
        :$path = "$:HOME/.ssh/{Str.random}"
    )^
    {
        ${
            $:ssh-keygen -q -N ''
            "-f$path"
            ("-t$_" if $type)
            ("-b$_" if ~$bits)
            !>error
        }
        ?? $path
        !! die "Unable to produce a ssh key pair at $path";
    }

    static method tmp(:$type = $:type, Int :$bits)^ {
        SSH-keypair.new(:$type, :$bits, path => File.tmp(:dir).add("{$type}_key"));
    }

    method fix-perms^ {
        $self.private-key-file.chmod('go-rwx');
        $self.public-key-file.chmod('go-w');
        $self;
    }
}

constant $:ssh-private-key;
constant File $:ssh-identity-file = ( File.tmp.chmod(600).write("$_\n") if $:ssh-private-key );
constant SSH-keypair $:ssh-keypair = if $:ssh-identity-file {
    $:ssh-identity-file-->SSH-keypair.generate-public-key;
    $:ssh-identity-file;
};

# TODO: make this a non-static blessed configuration file so you have multiple
# SSHds with different configuration locations
class SSHd {

    static method run(:$port = 22, Bool :$debug, SSH-keypair :$server-keys) {
        # I don't even...https://github.com/moby/moby/issues/19351
        if $:os ~~ Debian { File</var/run/sshd>.mkdir }

        ${
            $:sshd >debug/warn ('-ddd' if $debug) -p $port -D
            ("-h$_" if $server-keys)
         }
    }

    static method generate-missing-keys ${ $:ssh-keygen -A >debug/warn }

    static method get-keypair($type) -->SSH-keypair {
        $:ssh-conf-dir.add("ssh_host_{$type}_key")
    }

    static method set-keypair(SSH-keypair $new) {
        my $existing = SSHd.get-keypair($new.type);
        $new.public-key-file.copy-to: $existing.public-key-file;
        $new.private-key-file.copy-to: $existing.private-key-file;
    }

    static method authorize-key(SSH-public-key $key){
        $:authorized_keys.push: "{$key.keytype} {$key.key}";
    }

    static method config -->File {
        $:ssh-conf-dir.add('sshd_config');
    }
}
