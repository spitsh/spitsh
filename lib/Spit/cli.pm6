use Getopt::Parse;
use Spit::Compile;
use Spit::Util :spit-version;
use Spit::Sastify;
use Spit::Docker;
need Spit::Repo;
need Spit::Parser::YAML;

BEGIN my @opts =  (
    opt(
        :name<version>,
        on-use => -> | { say spit-version(); exit 0 },
        desc => 'Print version',
    ),
);

my constant $helper-image = "spit-helper:{spit-version}";

BEGIN my $match-os =  anon token {
    :my $os;
    <word>
    <?{ $os = sast-os($<word>.Str, match => $<word>); $os }>
    { $/.make: $os }
};

BEGIN my @compilation-opts =
opt(
    name => 'in-docker',
    alias => 'd',
    match => 'str',
    value-default => 'alpine',
    desc => 'Run in a container derived from <image>',
    placeholder => 'image',
    on-use => -> $in-docker, %res {
        %res<in-docker> = $in-docker;
        %res<os> //=  do if $in-docker ~~ m/<!after ':'> [\w|'-']+ <!before '/'>/ {
            sast-os($/.Str, match => $/)
        }
    }
),
opt(
    name => 'in-helper',
    alias => 'h',
    desc => 'Run in a container derived from the spit-helper image',
    on-use => -> $, %res {
        %res<in-helper> = True;
        %res<os> //= sast-os 'Spit-Helper';
    }
),
opt(
    name => 'in-container',
    alias => 'D',
    desc => 'Run in an existing docker container',
    match => 'str',
    placeholder => 'id'
),
opt(
    name => 'docker-socket',
    alias => 's',
    desc => 'Mounts /var/run/docker.sock into the container'
),
opt(
    name => 'RUN',
    desc => ‘Run on this computer's /bin/sh. (Be careful)’
),
opt(
    name => 'opts-file',
    alias => 'f',
    desc => 'JSON file to read options from',
    match => 'existing-file',
    placeholder => 'opts.json'
),
opt(
    name => 'target',
    desc => 'Sets the compilation stage to finish at. Can be: parse, stage1, stage2, stage3 or compile',
    placeholder => 'stage',
    match => /'stage'<[1..3]>|'parse'|'compile'/,
    default => 'compile',
),
opt(
    name => 'debug',
    desc => 'Output debugging info + timtings for each compilation stage',
),
opt(
    name => 'no-inline',
    desc => 'Turns off call inlining for debugging purposes'
),
opt(
    name => 'xtrace',
    alias => 'x',
    desc =>  'Puts "set -x" into the script'
),
opt(
    name => 'os',
    desc => 'Shortcut to set $:os',
    match => $match-os,
    placeholder => 'os name',
    default => sast-os('alpine'),
),
opt(
    name => 'opts',
    alias => 'o',
    placeholder => 'key=value',
    match => token {
        $<key>=[[<.identifier> ':']? <.identifier>] [
            | '=' $<value>=(<int>|| <str> || '')
            | '==' $<expr>=<.str>
        ]?
        {
            my $val := do with $<value> {
                when .<int>  { sastify .<int>.Str.Int }
                when .<str>  { sastify .<str>.Str }
                when ''      { sastify False }
                default      {  }
            }
            orwith $<expr> {
                late-parse(.Str, match => $<expr>)
            }
            else {
                sastify(True);
            }

            $/.make: Pair.new($<key>.Str, $val);
        }
    },
    desc => 'Option key:value or key=expression',
    on-use => -> $pair, %res {
        %res<opts>{$pair.key}  = $pair.value;
    }
);


BEGIN my @commands =  (
    {
        name => 'compile',
        desc => 'Compile a spook file',
        long-desc => q:to/END/,
        Compile a file as spook code and print the resulting shell
        script to stdout. The optional -d, -D, -h and --RUN flags run
        the resulting script in docker containers or on the machine itself.
        END
        opts => @compilation-opts,
        pos => [pos(
            name => 'src-file',
            match => 'existing-file'
        ),],
        example => q:to/END/,
        spit my_program.sp # compile and run in docker
        spit compile my_program.sp --os debian # compile for debian
        spit compile my_program.sp -d centos # compile and run in centos
        spit compile my_program.sp -o log # compile with $:log set to True
        END
    },
    {
        name => 'eval',
        desc => 'Compile a string as spook code',
        opts => @compilation-opts,
        pos => [pos(name => 'src')],
        example => q:to/END/,
        spit eval 'say "hello world"'
        # compile and run in docker
        spit eval 'say "hello world"' -d
        spit eval 'say $:os.name' -d=centos
        # compile for alpine
        spit eval 'say $:os.name' --os=alpine
        END
    },
    {
        name => 'prove',
        desc => 'Run prove(1) over spook test files',
        pos => [ pos(name => 'path')],
        opts => [
          opt(
              name => 'in-docker',
              match => 'str',
              alias => 'd',
              desc => 'Run tests in containers derived from a comma separated list of docker images',
          ),
          opt(
              name => 'in-container',
              match => 'str',
              alias => 'D',
              desc => 'Run tests in a comma separated list of existing docker containers',
          ),
          opt(
              name => 'in-helper',
              alias => 'h',
              desc => 'Run tests in container derived from spit-helper',
          ),
          opt(
              name => 'verbose',
              alias => 'v',
              desc => 'Run prove with -v'
          ),
          opt(
              name => 'jobs',
              alias => 'j',
              desc => 'The number of prove jobs',
              match => 'uint',
          ),
          opt(
              name => 'opts-file',
              alias => 'f',
              match => 'existing-file',
              desc => 'Options file to pass to tests',
          ),
          opt(
              name => 'opts',
              alias => 'o',
              match => 'str',
              on-use => -> $pair, %res { %res<opts>.push($pair) },
              desc => 'Options to pass to tests',
          ),
          opt(
              name => 'docker-socket',
              alias => 's',
              desc => 'Mount /var/run/docker.sock in containers specified by --in-docker',
          ),
          opt(
              name => 'os',
              match => $match-os,
              desc => 'Compile the tests for particular OS',
          ),
          opt(
              name => 'RUN',
              desc => ‘Runs the tests on this computer's /bin/sh’,
          )
        ]
    },
    {
        name => 'helper',
        desc => 'Build/remove/update the spit-helper image',
        long-desc => q:to/END/,
        Builds, removes or upgrades the spit-helper docker image. spit-helper
        is a small docker image pre-built with useful utilties for deploying
        shell scripts.
        END
        commands => (
           { name => 'build', desc => 'Builds the spit-helper docker image' },
           { name => 'clean', desc => 'Removes all spit-hepler docker images'}
        )
    },
);

constant $pre-usage = '';

constant $parser = Getopt::Parse.new(
    command => %(
        name => 'spit',
        :@opts,
        :@commands,
        pos => [pos(
            name => "src-file",
            match => 'existing-file',
            :!required,
            implicit-command => 'compile'
        )],
    ),
    :$pre-usage,
    opt-color-alternate => ( '', "\e[38;5;125m")
).gen-usage;

sub do-main() is export {
    my %cli := $parser.get-opts();

    given %cli<commands>[0] {
        when 'eval' {
            compile-src(%cli<src>, %cli, name => 'eval')
        }
        when 'compile' {
            compile-src(
                (%cli<src-file>.IO.slurp orelse .throw),
                %cli,
                name => %cli<src-file>
            )
        }
        when 'prove' {
            prove(%cli<path>, |%(%cli<in-docker docker-socket in-container opts-file
                                      opts in-helper jobs verbose os RUN>:p));
        }
        when 'helper' {
            helper(%cli<commands>[1]);
        }
        default {
            note $parser.usage();
            exit(1);
        }
    }
}

sub compile-src($src, %cli, :$name) {
    my @*repos = [
        Spit::Repo::File.new,
        Spit::Repo::Core.new
    ];

    my %opts;

    with %cli<opts-file> {
        %opts.append: .&parse-opts().pairs;
    }
    elsif '.spit.yml'.IO.e {
        %opts.append: '.spit.yml'.IO.&parse-opts().pairs;
    }

    %opts.append(.pairs) with %cli<opts>;

    %opts<os> //= %cli<os>;

    my ($docker,$promise) = do with %cli<in-docker> {
        start-docker $_, |(%cli<docker-socket>:p);
    }
    orwith %cli<in-helper> {
        start-docker $helper-image, :docker-socket;
    }
    orwith %cli<in-container> {
        exec-docker $_;
    }
    try my $shell = compile($src, |%(%cli<target no-inline xtrace debug>:p), :%opts, :$name).gist;

    if $! {
        .kill(SIGTERM) with $docker;
        note $!.gist;
        exit 1;
    }

    if $docker {
        my $proc = write-docker $docker, $promise, $shell;
        exit($proc.exitcode);
    } elsif %cli<RUN> {
        exit (run 'sh', '-c', $shell).exitcode;
    } else {
        print $shell;
    }
}

sub prove(Str:D $path, :$in-docker, :$in-container, :$in-helper,
          :$docker-socket, :$jobs, :$verbose, :$os, :$RUN, :@opts,
          :$opts-file
         ) {

    my @runs = |($in-docker andthen .split(',').map: { "-d=$_" }),
               |($in-container andthen .split(',').map({"-D=$_"})),
               |($in-helper andthen '-h'),
               |($RUN andthen '--RUN');

    @runs.push('-d=alpine') unless @runs;
    %*ENV<MVM_SPESH_INLINE_DISABLE> = "1";

    for @runs {
        my @run =
          "prove", ("-j$_" with $jobs),('-v' if $verbose),'-r', '-e',
          (
              "$*EXECUTABLE $*PROGRAM " ~
              'compile' ~
              (' -s' if $docker-socket) ~
              (" --os={$os.class-type.name}" if $os) ~
              (@opts.map: { " -o=$_" }).join ~
              (" -f=$opts-file" if $opts-file) ~
              " $_"
          ),
          $path;
        note "running: ", @run.perl;
        my $run = run @run;
        exit $run.exitcode unless $run.exitcode == 0;
    }
}


sub helper($_) {
    when 'build' {
        my ($helper-builder, $p) = start-docker('alpine', :docker-socket);
        my $build-helper-src =  %?RESOURCES<tools/spit-helper.sp>.absolute.IO;
        my $compile = compile(
            $build-helper-src.slurp,
            name => $build-helper-src,
            opts => {
                os => sast-os('alpine'),
                log => sastify(True),
            }
        );
        write-docker($helper-builder, $p, $compile);
    }
    when 'clean' {
        my @images = (run 'docker', 'images', '-f=label=spit-helper', '-q', :out).
                     out.slurp(:close).split("\n").grep(*.so).unique;

        if @images {
            exit (run 'docker', 'rmi', '-f', @images).exitcode;
        } else {
            say 'No spit-helper images';
        }
    }
}

multi parse-opts(Str:D $yaml) {
    my $res = Spit::YAML::Grammar.parse($yaml, actions => Spit::YAML::Actions);
    return Nil without $res;
    my %opts = $res.made[0].pairs.map: { .key => sastify(.value) }
    %opts;
}

multi parse-opts(IO::Path:D $yaml-file) {
    parse-opts($yaml-file.slurp)
      or die "Failed to parse $yaml-file as YAML -- sorry I can't tell you more!";
}
