use Spit::Compile;
need Spit::Exceptions;
use Spit::Util :light-load;

role Spit::Repo {

    method load(|c(:$repo-type,:$id!,:$debug)) {
        my $name = ($_ ~ '<' with $repo-type) ~ $id ~ ('>' if $repo-type);
        with self.resolve(|c) {
            when Str { compile($_,:target<stage2>,:$name,:$debug) }
            when *.isa('SAST::CompUnit') {
                proceed unless .stage2-done;
                $_;
            }
            default {
                SX::Bug.new(
                    desc => "{self.gist} returned an invalid SAST::CompUnit ({.gist})" ~
                    " while trying to load '$name'";
                ).throw;
            }
        }
    }
    proto method resolve(|) {*};
    multi method resolve(:$repo-type!,:$id!) { }
    multi method resolve(:$id!){ }

    method resolve-lib()  { }
}

class Spit::Repo::File does Spit::Repo {
    multi method resolve(:$repo-type!,:$id!) {
        if $repo-type eq 'file' {
            $id.IO.slurp
        }
    }

    method gist { self.^name }
}

class Spit::Repo::Core does Spit::Repo {

    sub get-CORE-lib($name) {
        (once light-load 'Spit::PRECOMP', export-target => '%core-lib'){$name};
    }

    multi method resolve(:$repo-type!,:$id!) {
        if $repo-type eq 'core' {
            get-CORE-lib($id) andthen .return;
        }
    }

    multi method resolve(:$id!) { get-CORE-lib($id) andthen .return }
}
