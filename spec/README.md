# The Spec
The spec tests define how complete this Spit compiler (or any other) is. They
all use the TAP based [Test.sp](../resources/core-lib/Test.sp)
module. It's split into multiple categories:

1. base: These define the core language. Anything in the core that
   doesn't mutate the machine state (apart from creating and removing
   temp files) belongs in there. They make sure that the userland's `/bin/sh` is
   interpreting our shell correctly and utilities like `awk`,`sed` etc
   are giving the right results. **Theoretically these are safe to run
   anywhere but do so at your own risk**
2. packages: Tests the installation, inspection and removal of
   packages. **Obviously only run these anywhere you don't mind
   packages being installed and removed**.

## Running the spec with docker

From the repo directory run:

``` shell
perl6 -Ilib bin/spit prove spec/base
```

## Compatability
Ideally I want this list to be automatically updated this is what works for now:

* base: Alpine,Debian and CentOS
* packages: Debian and CentOS
