# PID
 The PID class represents an integer process ID.
## Bool
>method Bool( ⟶ [Bool](./Bool.md))

 In Bool context the PID returns the result of `.exists`
## exists
>method exists( ⟶ [Bool](./Bool.md))

 Returns true if the process exists on the system.
## kill
>method kill([Str](./Str.md) **$signal** ⟶ [Bool](./Bool.md))

 Sends the process a signal. Returns true if the signal was successfully sent.
