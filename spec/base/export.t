plan 6;

use file<spec/base/lib/SomeModule.spit>;
use Test;

is exported-sub(),'foo',"sub was exported";
is Exported-Class.doit,'foo',"class was auto-exported";
is $exported-scalar,'exported scalar','export constant';
is $assign-to-block,'assign to block','export a constant assigned to a block';

is $assign-to-block-inlineable,'inlineable assignment','exported constant assigned to inlineable block';
is $inline-canary,'win','side effects of inlined block still happened';
