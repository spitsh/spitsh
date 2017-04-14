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
is File</etc/meaning-of-life.cfg>.read,'42',"configured with correct MOL";
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
# say
>sub say([Str](../Str.md) **$str** ⟶ [Bool](../Bool.md))

 Prints its argument to `$*OUT` with a newline
