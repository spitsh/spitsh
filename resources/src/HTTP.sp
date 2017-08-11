class HTTP-headers is List[Pair] {
    method content-type~ { $self<Content-Type> }
    method content-length~ { $self<Content-Length> }
    method content-encoding~ { $self<Content-Encoding> }
    method location~ { $self<Location> }
    method host~     { $self<Host> }
}

class HTTP-response is List[Pair] {
    constant $:error-max-length = 100;

    method headers -->HTTP-headers { $self<headers>-->File.slurp-->HTTP-headers }
    method req-method~ { $self<req-method> }
    method req-headers -->HTTP-headers { $self<req-headers>-->File.slurp-->HTTP-headers }
    method body~ { .slurp if $self<body>-->File  }
    method remote-url -->HTTP   { $self<remote-url>   }
    method body-size+ { $self<body-size>-->Int }
    method json -->JSON { $self.body-->JSON }
    method code+ { $self<code>-->Int }

    method charset~ {
        $self.headers.content-type
        .${ sed -rn 's/.*charset\s*=\s*"?([^"\s;]+)"?/\1/pi' }.uc;
    }
    method message~ { $self<message> }
    method http-version~ { $self<http-version> }

    method is-success? { $self.code.starts-with(2) }
    method is-redirect? { $self.code.starts-with(3) }
    method is-client-error? { $self.code.starts-with(4) }
    method is-server-error? { $self.code.starts-with(5) }
    method is-error? { $self.code.matches(/^[45]/) }

    method ok^ {
        if $self.is-success {
            $self;
        } else {
            die "{$self.req-method} {$self.remote-url} {$self.code} {$self.message}\n" ~
              ($self.body-size > $:error-max-length ?? $self.body.substr(0,$:error-max-length) ~ '...' !! $self.body)
        }
    }
}

augment HTTP {
    method get~ {
        ${ $:curl -fSsL $self }
    }

    method add($path) -->HTTP {
        "$self/$path";
    }

    method get-file(:$to)-->File {
        ${
            $:curl -fSsL -w '%{filename_effective}'
            ($to ?? "-o$to" !! '-O') $self
        }
    }

    method redirect-url-->HTTP {
        ${ $:curl -Isw '%{redirect_url}' -o '/dev/null' $self }
    }

    method is-https? {
        $self.starts-with('https');
    }

    method https^ {
        $self.${ sed -r 's§^(.*://)?§https://§' }
    }

    method query(Pair *@query) -->HTTP {
        if @query {
            my $query = (.key ~ '=' ~ .value for @query).join('&');
            if $self.contains('?') {
                $self ~ '&' ~ $query;
            } else {
                $self ~ '?' ~ $query
            }
        } else {
            $self;
        }
    }

    method request($method,
                   :@headers,
                   :$to,
                   :$max-redirects,
                   :$proxy,
                   Pair :@form,
                   JSON :$json) -->HTTP-response {
        my $headers = File.tmp;
        my $req-headers = File.tmp;
        debug "HTTP ==> $method $self", "\c[GLOBE WITH MERIDIANS]";
        my $response = ${
            # ✨ save all stderr output to $req-headers to be parsed later
            $:curl -svL !> $req-headers
            -X $method
            --max-redir ($max-redirects || 0)
            -D $headers
            -o ($to || File.tmp)
            ("-H$_" for ('Content-Type: application/json' if ~$json), @headers)
            # curl sends Expect 100-continue which is super annoying otherwise
            -H 'Expect:'
            ('--data-binary', $_ if ~$json)
            ("-x$_" if $proxy)
            ('--form-string', .key ~ '=' ~ .value for @form)
            -w (
                "headers\\t$headers\\n" ~
                "req-method\\t$method\\n" ~
                'local-ip\t%{local_ip}\n' ~
                'local-port\t%{local_port}\n' ~
                'remote-ip\t%{remote_ip}\n' ~
                'remote-port\t%{remote_port}\n' ~
                'remote-url\t%{url_effective}\n' ~
                'code\t%{http_code}\n' ~
                'content-type\t%{content_type}\n' ~
                'body-size\t%{size_download}\n' ~
                'body\t%{filename_effective}\n' ~
                'download-speed\t%{speed_download}\n' ~
                'total-time\t%{time_total}\n'
            )
            $self
        }-->HTTP-response;

        $headers.line-subst(/\r/,'',:g);
        $response.push: $headers.shift.${
            sed -r 's§HTTP/([^ ]+) [0-9]+ (.*)§http-version\t\1\nmessage\t\2\n§'
        };
        $req-headers.line-subst(/\r/,'',:g);
        # Keep only lines beggining with > (request header data)
        # and remove the >
        $req-headers.filter(/^> (.+)/,'\1');
        # Get rid of the GET request line
        $req-headers.shift;
        # Change the : to tabs to make it a List[Pair]
        $req-headers.line-subst(/: /,'\t',:g);
        $headers.line-subst(/: /,'\t');
        # Put the req-headers as an attribute of the response
        $response.push((:$req-headers));

        debug "HTTP <== {$response.code} {$response.message} $self", "\c[GLOBE WITH MERIDIANS]";
        $response;
    }
}
