constant Cmd $:sshd is export = {
    on {
        Alpine { Pkg<openssh>.ensure-install }
        Any    { Pkg<openssh-server>.ensure-install }
    }
    Cmd<sshd>.path;
}

constant Cmd $:ssh = on {
    Any {
        Cmd<ssh> or
        $:Pkg-openssh-client.install && 'ssh';
    }
    Spit-Helper { 'ssh' }
}

constant Cmd $:ssh-keygen = ($:ssh; 'ssh-keygen');
constant Cmd $:ssh-keyscan = ($:ssh; 'ssh-keyscan');
constant $:ssh-known-hosts is export = $:HOME.add('.ssh').mkdir.add('known_hosts');
constant $:ssh-conf-dir = File</etc/ssh>;
constant $:authorized_keys is export = $:HOME.add('.ssh').mkdir.add('authorized_keys');

class SSH-known-host is Str is primitive { }

class SSH-publickey is Str is primitive {
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
}



augment SSH-known-host  {
    method public-key -->SSH-publickey {
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

class SSH-keypair is Pair[File,File] {
     method private-key-file -->File { $self.key }
     method public-key-file -->File  { $self.value }
     method private-key~             { $self.key.slurp }
     method type~                    { $self.public-key.type }
     method keytype~                 { $self.public-key.keytype }
     method remove?                  ${rm $self.key $self.value !>X}
     method exists?                  { $self.key and $self.value }
     method Bool                     { $self.exists }
     method public-key -->SSH-publickey { $self.value.slurp-->SSH-publickey }

     static method new(
         :$type,
         Int :$bits,
         :$path = "$:HOME/.ssh/{Str.random}"
     )^
     {
         ${
             $:ssh-keygen -q -N ''
             "-f$path"
             ("-t$_" if $type)
             ("-b$_" if ~$bits)
             !>error:🐡
         }
         ?? ($path => "$path.pub")
         !! die "Unable to produce a ssh key pair at $path";
     }

     static method tmp(:$type, Int :$bits)^ {
         SSH-keypair.new(:$type, :$bits, path => File.tmp(:dir).add("tmp_$type"));
     }

}

# TODO: make this a non-static blessed configuration file so you have multiple
# SSHds with different configuration locations
class SSHd {

    static method run(:$port = 22, Bool :$debug) {
        # I don't even...https://github.com/moby/moby/issues/19351
        if $:os ~~ Debian { File</var/run/sshd>.mkdir }

        ${$:sshd >debug:🐡 !>warn:🐡 ('-ddd' if $debug) -p $port}
    }

    static method generate-missing-keys ${ $:ssh-keygen -A >debug:🐡 !>warn:🐡 }

    static method get-keypair($type) -->SSH-keypair {
        $:ssh-conf-dir.add("ssh_host_{$type}_key") => $:ssh-conf-dir.add("ssh_host_{$type}_key.pub")
    }

    static method set-keypair(SSH-keypair $new) {
        my $existing = SSHd.get-keypair($new.type);
        $new.public-key-file.copy-to: $existing.public-key-file;
        $new.private-key-file.copy-to: $existing.private-key-file;
    }

    static method authorize-key(SSH-publickey $key){
        $:authorized_keys.push: "{$key.keytype} {$key.key}";
    }

    static method config -->File {
        $:ssh-conf-dir.add('sshd_config');
    }
}
