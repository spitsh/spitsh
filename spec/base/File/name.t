use Test; plan 2;

{
    my File $file = "/etc/hosts/";
    is $file.parent,"/etc",'.parent';
    is $file.name,'hosts','.name';
}
