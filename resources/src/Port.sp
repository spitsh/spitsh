class Port is Int {
    method serve-file(File $file) {
        ${exec $:socat >debug/warn('serve-file') -U
          "TCP-LISTEN:$self,reuseaddr,fork" "FILE:$file"
        }
    }

    method tail-file(File $file) {
        ${exec $:socat -ls !>warn('tail-file') >debug('tail-file')
          # cool-write is to ignore all the useless EPIPE warnings
          # (plz explain if you know why there are EPIPE in this situation)
          -U "TCP-LISTEN:$self,reuseaddr,fork,cool-write" "EXEC:tail -f $file"
         }
    }

    method serve-script(File $script) {
        ${exec $:socat
          "TCP-LISTEN:$self,reuseaddr,fork"
          "EXEC:sh $script"
         }
    }

    method serve-executable(File $executable) {
        ${exec $:socat
          "TCP-LISTEN:$self,reuseaddr,fork"
          "EXEC: $executable"
         }
    }

    method listening-->List[PID] on {
        Linux ${
            $:netstat -lpn
            | awk -v "p=$self"
            '$4 ~ ":"p"$"{ sub("/.*","",$7); print $7 }'
            | uniq
        }
        Debian ${
            $:ss -lpn
            | awk -v "p=$self"
              '$5 ~ ":"p"$"{ sub(/.*pid=/,"",$7); sub(/,.*/,"",$7); print $7}'
            | uniq
        }
    }

    static method random^ on {
        Linux {
            while (
                my Port $port = ${shuf -n 1 -i 1024-65535};
                ${$:netstat -a | awk -v "p=$port" '($4 ~ ":"p"$"){f=1}END{exit !f}'}
            ) {;}
            $port;
        }
        Debian {
            while (
                my Port $port = ${shuf -n 1 -i 1024-65535};
                ${$:ss -a | awk -v "p=$port" '($5 ~ ":"p"$"){f=1}END{exit !f}'}
            ) {;}
            $port;
        }
    }
}
