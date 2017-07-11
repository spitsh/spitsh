use Test;

plan 5;

File.tmp(:dir).cd;


File<hello.c>.write: q{
    #include <stdio.h>
    int main(void)
    {
        printf ("hello world");
        return 0;
    }
};

File<Makefile>.write: q{
CC      = gcc
CFLAGS  = -g
RM      = rm -f

default: all

all: hello

hello: hello.c
	$(CC) $(CFLAGS) -o hello hello.c

clean:
	$(RM) hello
};

ok ${ $:gcc-make }, 'make ran';

my $exec = File<./hello>;
ok $exec, 'executable created';
$exec.chmod(500);
is ${ $exec }, "hello world", 'executable ran';

ok ${ $:gcc-make clean }, 'make clean';
nok $exec, 'executable removed';
