# FD
 FD wraps an integer representing a file descriptor. Usually you don't create these directly but get them through calling other methods like `File.open-w()`.
## close
>method close()


 Closes redirection for this file descriptor.
## dup
>method dup([FD](./FD.md) **$new-fd**)


 Duplicate the invocant file descriptor into the argument file descriptor like `DUP(2)` if the argument file descriptor is open it will be closed before becoming the alias.

|Parameter|Description|
|---------|-----------|
|**$new-fd**| The file descriptor to use as the alias|
## get
>method get( ⟶ [Bool](./Bool.md))


 Reads all data up to and **including** the next newline or up to the EOF and puts it into `$~`. The newline (if any) will be discarded.
## getc
>method getc([Int](./Int.md) **$n** ⟶ [Bool](./Bool.md))


 Reads a fixed number of characters

|Parameter|Description|
|---------|-----------|
|**$n**| The number of characters to read|
## is-open
>method is-open( ⟶ [Bool](./Bool.md))


 Returns True if the file descriptor is open.
## next-free
>method next-free( ⟶ [FD](./FD.md))


 Gets the next free file descriptor. **note:** This only kinda works.
## open-r
>method open-r([File](./File.md) **$file**)


 Opens a file for reading from this file descriptor.

|Parameter|Description|
|---------|-----------|
|**$file**| The file to open|
## open-rw
>method open-rw([File](./File.md) **$file**)


 Opens a file for reading and writing from this file descriptor.

|Parameter|Description|
|---------|-----------|
|**$file**| The file to open|
## open-w
>method open-w([File](./File.md) **$file**)


 Opens a file for writing from this file descriptor.

|Parameter|Description|
|---------|-----------|
|**$file**| The file to redirect to|
## tty
>method tty( ⟶ [Bool](./Bool.md))


 Returns whether this file descriptor is linked to a terminal.
```perl6
say $*OUT.tty;  #probably true
say FD<42>.tty; #probably false
```
## write
>method write([Str](./Str.md) **$data**)


 Writes to the file descriptor.

|Parameter|Description|
|---------|-----------|
|**$data**| The data to write to the file descriptor|
