# List
 The List type represents strings separated by newlines `\n`. It provides a familiar way of working with array-like data. However, because of the limitations of shell, you can't have discrete elements with newlines in them. You can type the List's elements by declaring a `@` variable with type before it or by putting `[type]` after `List`.
```perl6
my Int @ints = 1..10;
my List[Int] $ints = 1..10;
say @ints[0].WHAT #-> Int
```
## Int
>method Int( ⟶ [Int](./Int.md))

 The list in Int context returns `.elems`
```perl6
my @a = <one two three>;
say +@a; #-> 3
```
## at-pos
>method at-pos([Int](./Int.md) **$i** ⟶ Elem-Type)

 `at-pos` is the internal method called when the a list is accessed with the postcircumfix syntax `[..]`. It returns data typed as the element type (Str by default).
```perl6
my @list = <one two three>;
say @list.at-pos(1); #-> two
say @list[1]; #-> two
```

|Parameter|Description|
|---------|-----------|
|**$i**| the index to return the line at|
## elems
>method elems( ⟶ [Int](./Int.md))

 Returns the number notional elements in the list. This is equal to 0 if the list is the empty string otherwise the number of `\n` + 1.
## join
>method join([Str](./Str.md) **$sep** ⟶ [Str](./Str.md))

 Returns the result of removing the `\n` between each line and replacing it with a new separtor.

|Parameter|Description|
|---------|-----------|
|**$sep**| The separator to join on|
## pop
>method pop( ⟶ [List](./List.md))

 Removes a line from the end of the list
```perl6
my @a = <one two three>;
@a.pop;
```
## push
>method push(Elem-Type **$item** ⟶ [List](./List.md))

 Push an element onto the end of the list. If the list doesn't end in a newline one will be added before adding the new data.
```perl6
my @a;
for <one two three> {
    @a.push($_);
}
```

|Parameter|Description|
|---------|-----------|
|**$item**| The item to add to the list|
## set-pos
>method set-pos([Int](./Int.md) **$pos**, Elem-Type **$item** ⟶ [List](./List.md))

 `set-pos` is the internal method called which you set a list element using the postcircumfix syntax `[..]`.
```perl6
my @a = <one two three>;
@a[1] = "deux";
```
## shift
>method shift( ⟶ [List](./List.md))

 Removes the first line from the list
```perl6
my @a = <one two three>;
@a.shift;
say @a;
```
## unshift
>method unshift(Elem-Type **$item** ⟶ [List](./List.md))

 Adds a line to the front of the list.
```perl6
my @a = <one two three>;
@a.unshift("zero");
```

|Parameter|Description|
|---------|-----------|
|**$item**| The item to add to the list|
