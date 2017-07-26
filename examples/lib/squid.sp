constant $default-port = 3128;

class Squid-Conf is File {
    method port --> Port {
        ($self.capture(/http_port\s+(.+)/) || $default-port)-->Port
    }
}

class Squid {

    constant Pkg $:pkg is export = on {
        Debian { 'squid3' }
        RHEL   { 'squid'  }
        Alpine { 'squid' }
    }
    constant $:service-name = 'squid';
    constant Squid-Conf $:conf = "/etc/squid/squid.conf";
    constant Port $:port = $default-port;
    constant Cmd $:cmd is logged-as("\c[SQUID]") = $:pkg-->Cmd.ensure-install;
    constant File $:access-log = '/var/log/squid/access.log';

    static method run {
        info "starting squid on port {$:conf.port}";
        ${ $:cmd '-N' '-d1' -f $:conf !>debug };
    }

    static method write-conf(
        :$port = $:port,
        :@allowed-src,
        :$allow-localnet = True
    ) {
        $:conf.parent.mkdir;
        $:conf.remove;
        info "writing squid conf to $:conf";
        if $allow-localnet {
            $:conf.append: Q{
                acl localnet src 10.0.0.0/8      # RFC1918 possible internal network
                acl localnet src 172.16.0.0/12   # RFC1918 possible internal network
                acl localnet src 192.168.0.0/16  # RFC1918 possible internal network
                acl localnet src fc00::/7        # RFC 4193 local private network range
                acl localnet src fe80::/10       # RFC 4291 link-local (directly plugged) machine
                http_access allow localnet
            }
        }

        $:conf.append: qq{{
            { "acl allowed src $_" for @allowed-src }

            http_port $port
            http_access allow localhost

            { @allowed-src && 'http_access allow allowed'  }

            forwarded_for off
            request_header_access All allow all
        }};
    }

    static method service --> Service {
        name => $:service-name
    }

}
