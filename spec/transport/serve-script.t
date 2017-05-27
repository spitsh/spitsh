use Test;

plan 3;

given Port.random {
    my $pid = start .serve-script: File.tmp.write: eval{
        say $~.uc while $?IN.get;
    };
    sleep 1;
    ok .listening, '.listening after .serve-script';
    is .listening, $pid, '.listenting PID is the one we started';
    is Host.local.write-port($_, "hello\nworld"), "HELLO\nWORLD",
      '.write-port to .serve-script';
}
