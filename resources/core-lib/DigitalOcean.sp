class DO { } # defined below
#| Represents a DigitalOcean API ID
class DO-ID is Int { }

#| A DigitalOcean API response
class DO-API-response is HTTP-response {
    #| Checks the Digital Ocean API returned a successful HTTP
    #| response. If not, it will `die` with the error message from the api.
    method ok^ {
        if $self.is-success {
            $self
        }
        else {
            die "{$self.req-method} {$self.remote-url} {$self.code} {$self.message}\n" ~
            $self.json<message>;
        }
    }

}
#| Represents a Digital Ocean VM
class Droplet is JSON {
    method DO-ID { $self<id>-->Int }
    method name~ { $self<name> }
    method valid? { $self.DO-ID.valid }
    method delete -->DO-API-response {
        if $self.status eq 'new' {
            warn "{$self.name}: Waiting to be created before deleting", "\c[DROPLET]";
            $self.wait-till-active;
        }
        debug "{$self.name}: Deleting", "\c[DROPLET]";
        DO.delete($self)
    }
    method refresh -->Droplet { $self.merge: DO.droplet($self) }
    method status~ { $self<status> }
    method wait-till-active -->Droplet {
        debug "Waiting to be active", "\c[DROPLET]:{$self.name}";

        while (my $refresh = $self.refresh; $refresh.status eq 'new') { sleep 10 }

        $refresh.status eq 'active' or
          fatal "{$self.name}: Status wasn't active, got '{$refresh.status}' instead", "\c[DROPLET]";

        info "{$self.name}: Active at {$refresh.ipv4}", "\c[DROPLET]";
        $refresh;
    }
    method ipv4 --> Host {
        $self<networks><v4>[0]<ip_address>
    }
}

class DO-region is JSON {
    method name~      { $self<name> }
    method slug~      { $self<slug> }
    method features@  { $self<features> }
    method sizes@     { $self<sizes> }
    method available? { $self<available> }
}

class DO-image is JSON {
    method DO-ID   { $self<id>-->Int }
    method name~   { $self<name>   }
    method slug~   { $self<slug>   }
    method public? { $self<public> }
    method type~   { $self<type>   }
    method size~   { $self<size_gigabytes> }
    method distribution~ { $self<distribution> }
    method min-disk-size+ { $self<min_disk_size>-->Int }
    method regions --> List[DO-region] { $self<regions>.List-->List[JSON] }
}

class DO-key is JSON {
    method DO-ID { $self<id>-->Int }
    method fingerprint~ { $self<fingerprint> }
    method name~        { $self<name> }

    method private-key-file --> File  { $self<private-key-file> }
    method public-key~  { $self<public_key> }

    method delete -->DO-API-response { DO.delete-key($self) }
    method exists?                   { DO.exists-key($self) }

    constant $key-cleanup = File.tmp;

    method cleanup^ {
        $key-cleanup.push($self);
        END { .delete for $key-cleanup.slurp-->List[DO-key] }
    }
}

constant File $droplet-cleanup = ${mktemp};

augment DO {

    constant $:api-token is required;
    constant $:api-version = 'v2';
    constant HTTP $:api-url = "https://api.digitalocean.com/$:api-version";
    constant HTTP $:metadata-url = 'http://169.254.169.254/metadata/v1';
    constant $:region = 'nyc1';
    constant @:ssh-keys =  $:ssh-keypair.public-key.fingerprint(:algo<md5>);
    constant $:size = '512mb';
    constant $:image = 'debian-9-x64';
    constant $:seed-port = 2222;


    static method images(:$type) -->List[DO-image] {
        DO.request(
            'GET',
            "images",
            query => (per_page => 200, (:$type if $type))
        ).ok.json<images>.List-->List[JSON]
    }

    static method regions -->List[DO-region] {
        DO.request('GET', 'regions').ok.json<regions>.List-->List[JSON]
    }

    static method droplets -->List[Droplet] {
        DO.request('GET','droplets').ok.json<droplets>.List-->List[JSON]
    }

    static method create(
              :$name = Str.random,
              :$region = $:region,
              :$size = $:size,
              :$image = $:image,
              :@ssh-keys = @:ssh-keys,
              :$on-boot
    ) --> Droplet
    {
        my $json = {
            :$name,
            :$region,
            :$size,
            :$image,
            ssh_keys => @ssh-keys,
            user_data => "#!/bin/sh\n$on-boot"
        };

        info "Creating droplet ($name $region $size $image)", "\c[WATER WAVE]";
        DO.request('POST', 'droplets', :$json).ok.json<droplet>;
    }

    static method create-ssh-seeded(
        :$name = Str.random,
        :$region = $:region,
        :$size   = $:size,
        :$image  = $:image,
        :@ssh-keys = @:ssh-keys
    ) -->Droplet {
        my $seed-keys = SSH-keypair.tmp;
        my $seed-public-key = $seed-keys.public-key;
        my $seed-private-key = $seed-keys.private-key;

        my $set-ssh-keys = eval(
            os => UNIXish,
            :!log,
            sshd => '/usr/sbin/sshd', # DO always has ssh installed
        ){
            my $keydir = File</tmp/spit-seed>.mkdir.cleanup;
            $keydir.add('seed_ssh.pub').push: $seed-public-key;
            my SSH-keypair $seed-keys = $keydir.add('seed_ssh').push: $seed-private-key;
            $seed-keys.fix-perms;
            SSHd.run(port => $:seed-port, server-keys => $seed-keys);
        };

        my $droplet = DO.create(
            :@ssh-keys,
            on-boot => $set-ssh-keys,
            :$region,
            :$size,
            :$image,
            :$name,
        );

        debug "{$droplet.name}: Wating 30 seconds for to boot", "\c[DROPLET]";

        sleep 30;
        $droplet .= wait-till-active;
        my $ip = $droplet.ipv4;
        $seed-keys.public-key.known-host($ip).add;

        $ip.wait-connectable($:seed-port, :timeout(40))
          or fatal "{$droplet.name}: ssh seeding failed: seed port $:seed-port never opened for", "\c[DROPLET]";

        $droplet;
    }

    static method delete(DO-ID $id) -->DO-API-response {
        info "Deleting droplet $id", "\c[WATER WAVE]";
        DO.request('DELETE', "droplets/$id")
    }

    static method droplet(DO-ID $id) -->Droplet {
        DO.request('GET', "droplets/$id").ok.json<droplet>
    }

    static method keys -->List[DO-key] {
        DO.request('GET', 'account/keys').ok.json<ssh_keys>.List-->List[JSON]
    }

    static method create-key(SSH-public-key $public-key, :$name = Str.random) -->DO-key {
        info "Creating key $name ({$public-key.fingerprint})", "\c[WATER WAVE]";
        DO.request('POST', 'account/keys', json => (:$name, public_key => $public-key))
          .ok.json<ssh_key>;
    }

    static method ensure-key(SSH-public-key $public-key, :$name = Str.random) {
        my $fingerprint = $public-key.fingerprint(:algo<md5>);
        DO.exists-key($fingerprint)
          ?? debug "ssh key $fingerprint already exists", "\c[WATER WAVE]"
          !! DO.create-key($public-key, :$name);
    }

    static method get-key($fingerprint) --> DO-key {
        DO.request('GET', "account/keys/$fingerprint").ok.json<ssh_key>;
    }

    static method exists-key($fingerprint)? {
        DO.request('GET', "account/keys/$fingerprint").is-success;
    }

    static method delete-key($fingerprint) -->DO-API-response {
        info "Deleting key $fingerprint", "\c[WATER WAVE]";
        DO.request('DELETE', "account/keys/$fingerprint")
    }

    static method request($method, $resource, Pair :@query, JSON :$json) --> DO-API-response {
         $:api-url.add($resource).query(@query).request(
            $method,
            :$json,
            headers => ("Authorization: Bearer $:api-token"),
        );
    }

    static method tmp(:$region,:$size,:$image) -->Droplet {
        my $temp-droplet = DO.create(name => 'tmp-' ~ Str.random, :$region, :$size, :$image);
        $droplet-cleanup.push: $temp-droplet;
        $temp-droplet;
        END {
            my @droplets = $droplet-cleanup.slurp-->List[Droplet];
            if @droplets {
                info "starting droplet cleanup";
                for @droplets { .delete }
            } else {
                debug 'no droplets to cleanup';
            }
            $droplet-cleanup.remove;
        }
    }

    static method metadata-request($resource)~ ${
        $:curl -s $:metadata-url.add($resource)
    }

    static method my-id -->DO-ID {
        DO.metadata-request('id')-->DO-ID
    }

    static method my-metadata -->JSON {
        DO.metadata-request('.json')
    }

}


augment Droplet {
    method ssh-seed($shell)~ {
        $self.ipv4.ssh(
            port => $DO:seed-port,
            $shell,
        )
    }
}
