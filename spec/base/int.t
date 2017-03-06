use Test;

plan 4;

nok 0,"zero is false";

{
    my Int $i = 0;
    is ++$i,1,"pre-increment works";
}
{
    my $i = 0;
    is $i++,0,"post-increment doesn't immediately incrememnt";
    is $i,1,"post-inrement increments";
}
