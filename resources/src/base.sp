# The Following are predeclared in Spit::Metamodel
class Any {}    # is primitive
class Str  {}   # is Any is primitive
class Int  {}   # is Str is primitive
class Bool {}   # is Str is primitive
class List {}   # List[Elem-Type] is Str is primitive
class Regex {}  # is Str
class EnumClass {} # is Str is primitive
class Pattern {} # is Str
class FD {} # is Int
class File {} #
class PID {} # is Int
class Pair {} # is Str is primitive

class JSON { } # is Str is primitive
class DateTime { }
class HTTP {}
class Host {}
class Cmd {}
enum-class OS { }
