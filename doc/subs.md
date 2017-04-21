# die
>sub die([Str](../Str.md) **$str**)

 Prints the message to stdout and then exits
# flunk
>sub flunk([Str](../Str.md) **$msg**)

 Prints a message and dies angrily ✘.
# is
>sub is([Str](../Str.md) **$a**, [Str](../Str.md) **$b**, [Str](../Str.md) **$msg**)

 If the two strings are equal, prints the message with a friendly '✔'. Otherwise, displays the two strings and dies with an angry '✘'.
```perl6
is File</etc/meaning-of-life.cfg>.slurp,'42',"configured with correct MOL";
```

|Parameter|Description|
|---------|-----------|
|**$a**| The string to check|
|**$b**| The expected string|
|**$msg**| The associated message|
# list
>sub list([List](../List.md) ***@list** ⟶ [List](../List.md))

 Joins arguments on a `\n` creating a `List`.
# nok
>sub nok([Bool](../Bool.md) **$cond**, [Str](../Str.md) **$msg**)

 The negated form of `ok`. Succeeds when the $cond is false.
# note
>sub note([Str](../Str.md) **$str** ⟶ [Bool](../Bool.md))

 Prints its argument to `$*ERR` with a newline.
# ok
>sub ok([Bool](../Bool.md) **$cond**, [Str](../Str.md) **$msg**)

 If the condition true, ok prints the message with a friendly '✔'. Otherwise, dies with an angry '✘'.
```perl6
ok True,"";
```

|Parameter|Description|
|---------|-----------|
|**$cond**| The success condition|
|**$msg**| The associated message|
# pass
>sub pass([Str](../Str.md) **$msg**)

 Prints a message with a friendly ✔.
# print
>sub print([Str](../Str.md) **$str**)

 Prints its argument to `$*OUT` with no newline.
# prompt
>sub prompt([Str](../Str.md) **$question**, [Bool](../Bool.md) **:$default** ⟶ [Bool](../Bool.md))

 Prompts the user with a yes/no question and returns a Bool with the answer. If `$*interactive` is false then it will just return the default.
```perl6
if prompt("Did the chicken come before the egg?", :default(True)) {
    say "wrong, the egg came before the chicken.";
} else {
    say "wrong, the chicken DID come before the egg.";
}
```

|Parameter|Description|
|---------|-----------|
|**$question**| The question to pose to the user|
|**:$default**| The default answer|
# say
>sub say([Str](../Str.md) **$str** ⟶ [Bool](../Bool.md))

 Prints its argument to `$*OUT` with a newline
# sleep
>sub sleep([Int](../Int.md) **$seconds**)

 Suspends execution for an interval of time measured in seconds. **note** `sleep(1)` can usually take floating point numbers but they are NYI in spit.
