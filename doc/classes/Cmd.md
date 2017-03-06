# Cmd
 Cmd represents a name or path of a command in the shell.
## Bool
>method Bool( ⟶ [Bool](./Bool.md))


 Cmd returns `.exists` in Bool context
```perl6
if Cmd<curl> || Cmd<wget> -> $ua {
    say "$ua is here, it can be our http user agent";
}
```
## exists
>method exists( ⟶ [Bool](./Bool.md))


 Returns true if the command can be found in the current shell enironment.
```perl6
 my Bool $have-node = Cmd<node>.exists
```
