# FD
 FD wraps an integer representing a file descriptor. Usually you don't create these directly but get them through calling other methods like `File.open-w()`.
## close-w
>method close-w()


 Closes redirection for this file descriptor.
## next-free
>method next-free( ⟶ [FD](./FD.md))


 Gets the next free file descriptor. **note:** This only kinda works.
## open-file-w
>method open-file-w([File](./File.md) **$file**)


 Redirects output from the invocant file descriptor to the file.

|Parameter|Description|
|---------|-----------|
|**$file**| The file to redirect to|
## open-w
>method open-w([FD](./FD.md) **$dst**)


 Redirects output from the invocant file descriptor to the argument file descriptor.

|Parameter|Description|
|---------|-----------|
|**$dst**| The file descriptor to redirect to|
## read
>method read( ⟶ [Str](./Str.md))


## tty
>method tty( ⟶ [Bool](./Bool.md))


 Returns whether this file descriptor is linked to a terminal.
```perl6
say $*OUT.tty;  #probably true
say FD<42>.tty; #probably false
```
## writable
>method writable( ⟶ [Bool](./Bool.md))


 Returns if the file descriptor is writable.
## write
>method write([Str](./Str.md) **$data**)


 Writes to the file descriptor.

|Parameter|Description|
|---------|-----------|
|**$data**| The data to write to the file descriptor|
