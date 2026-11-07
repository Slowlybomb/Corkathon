# Century

Century is a compiled programming language with a strict type checker. Nothing
converts implicitly: `u32 + u64` is an error until you write `u64(x)`, and any
type error stops compilation before code is generated. A program compiles
straight to native x86-64 machine code, either run at once (`--jit`) or saved
as a standalone `.exe` (`--build`), and runs its marked loops on every CPU
thread (`cpu do`) or on the GPU (`gpu do`). A reference interpreter that checks
every array access is built in for debugging.

| File | What it is |
|---|---|
| `century.exe` | The compiler and runner. Windows 10 or 11, 64-bit. Needs no installation and no other files. |
| `CENTURY.md` | This guide. |

To use the GPU, the machine needs a current graphics driver with Vulkan 1.1 or
later (any recent NVIDIA, AMD or Intel driver has it). Without one, everything
still runs, on the CPU.

`century.exe` is not code-signed. If Windows shows "Windows protected your PC"
the first time, choose **More info**, then **Run anyway**. If it came in a zip
file and refuses to start, open its Properties and tick **Unblock**.

**Contents**

1. [Quick start](#1-quick-start)
2. [Running programs](#2-running-programs)
3. [Your machine: the device scan](#3-your-machine-the-device-scan)
4. [The language](#4-the-language)
5. [Built-in functions](#5-built-in-functions)
6. [Making it fast](#6-making-it-fast)
7. [What does not work yet](#7-what-does-not-work-yet)
8. [Every command-line flag](#8-every-command-line-flag)
9. [Environment variables](#9-environment-variables)
10. [Errors and how to fix them](#10-errors-and-how-to-fix-them)
11. [A complete example](#11-a-complete-example)

---

## 1. Quick start

Save this as `hello.cy`:

```
-- hello.cy: the sum of the squares 1..n
pub fn main(n: u32) -> u64
    mut total = u64(0)
    mut i = u32(1)
    while i <= n do
        total = total + u64(i * i)
        i = i + u32(1)
    end
    return total
end
```

Then run it from a terminal in the same folder:

```
century hello.cy --jit main --arg 10
```

```
hello.cy: ok - 0 types, 1 functions, 52 tokens, 26 nodes, 46 interned
jit main: 256 bytes (module 256)
jit main = 385
```

The first line is the type check, the second is the size of the machine code it
made, and the third is what `main(10)` returned.

To make a program you can run on its own, as with a C compiler:

```
century hello.cy --build hello.exe
hello.exe 10
```

prints `385`. Section 2.5 has the details.

In **cmd**, `century` works from the folder that holds `century.exe`. In
**PowerShell**, type `.\century` instead, or add the folder to your `PATH` to
use it from anywhere.

Before anything else on a new machine, run `century --device` (section 3).

---

## 2. Running programs

### 2.1 How a run works

- A program is one or more `.cy` files. There is no required `main`: you name
  the function to run with `--jit` or `--ir-run`.
- That function takes integer or `bool` parameters, whose values come from
  `--arg`, and returns a number, a `bool`, or nothing.
- **Century has no print statement.** A run shows the function's return value.
  Anything more goes to a file with `writefile` (section 4.23), or out through an
  operating-system call (section 4.22).

### 2.2 The main commands

| Command | What it does |
|---|---|
| `century prog.cy` | Checks the program (parse and types) and reports every error. Runs nothing. |
| `century prog.cy --jit f --arg 5` | Compiles the whole program to x86-64 machine code in memory and runs `f(5)`. The quickest way to try something. |
| `century prog.cy --build prog.exe` | Compiles the program once into a standalone executable, which you then run as `prog.exe 5` (section 2.5). |
| `century prog.cy --ir-run f --arg 5` | Runs `f(5)` on the interpreter. Much slower, but every array access is checked. For debugging. |
| `century --device` | Reports this machine's CPU and GPU and what Century will do with them (section 3). |
| `century --help` / `century --version` | Usage summary / build date. |

Every flag is listed in section 8.

### 2.3 Arguments

- Give `--arg N` once per parameter, in order: `--jit f --arg 1 --arg 2`.
- `N` is a whole number in decimal. Negative numbers work for signed
  parameters: `--arg -21`.
- `--jit` passes at most **eight** arguments. `--ir-run` passes any number.
- The function you run must take integers or `bool`. A float cannot come from
  the command line: take an integer and convert it inside, as in `f64(n) / 100.0`.

### 2.4 Reading the result

The result line is always the raw value as an unsigned 64-bit integer, which is
what scripts should read. For a float, or a negative signed number, a second
line gives the actual value:

```
jit areas = 4634324203794507530
jit areas as f64 = 65.707963267948941
```

```
jit c_negarg = 4294967254
jit c_negarg as i32 = -42
```

- A `bool` prints `1` or `0`.
- A function that returns nothing prints `jit f: done (it returns nothing)`.
- For a negative `i8`, `i16` or `i32` result, the raw number can differ
  between `--jit` and `--ir-run`, which leave different bits above the value.
  The `as` line is the same on both.

### 2.5 Building a program: `--build`

`--jit` compiles the program every time it runs. `--build` compiles it once,
into an executable that runs on its own, the way a C or Rust compiler does:

```
century hello.cy --build hello.exe
hello.exe 10
```

```
hello.cy: ok - 0 types, 1 functions, 52 tokens, 26 nodes, 46 interned
built hello.exe: 256 bytes of machine code, starting at main
385
```

- **The program starts at the function `main`.** `--entry f` picks another.
  `--build` with no file name writes `hello.exe` (the source's name) into the
  current folder.
- **Each word on the command line is one parameter** of that function, in
  order. The entry takes up to eight whole numbers or `bool`s (`true`,
  `false`, `1` or `0`). Every word is checked for its type and range, and a
  wrong one stops the program with what it expects:

  ```
  hello.exe: `ten` is not a u32 for n (a whole number from 0 to 4294967295)
  usage: hello.exe <n: u32>
  ```
- **The result is printed on its own line**: a number, `true` or `false`, or
  nothing at all for a function that returns nothing. A float is printed with
  as few digits as read back to exactly the same value (`65.70796326794894`).
  The program then exits with code 0.
- **It needs nothing else**: not `century.exe`, not the source, no DLL beyond
  Windows' own. Copy the one file to any 64-bit Windows 10 or 11 machine and
  run it. It is about 3.7 MB, almost all of it Century's runtime (memory,
  threads, the GPU interface), which the machine code calls into.
- **Starting it compiles nothing.** It loads its machine code, points the
  code's calls at the runtime and at any `extern` functions, and runs. On the
  laptop of section 3, a 6,500-line fluid solver with GPU kernels takes 0.65 s
  per run under `--jit`, 0.45 s of it compiling, and 0.2 s as a built program.
- **Fixed when it is built:** the code, and every flag given to `--build`
  (`--opt`, `--fma`, `--no-gpu`, `--gpu-approx`, `--no-parallel`).
  **Decided when it runs:** the number of threads, which GPU (or none), and
  where each `extern` function is: they are looked up by library and name, so
  the program works on other versions of Windows.
- A built program needs a CPU with AVX2, FMA and BMI2 (section 3), and checks
  before it runs anything. There is no interpreter inside it to fall back on:

  ```
  hello.exe: this CPU has no AVX2, FMA, which this program needs
  ```
- The environment variables of section 9 work on a built program too, for
  example `CY_THREADS=4` or `CY_GPU_STATS=1`.
- Building again replaces the file. If the old one is still running, the build
  says so instead.

---

## 3. Your machine: the device scan

`century --device` reads the CPU's instruction sets and every GPU Vulkan
reports, then says what Century will do with them. This is the output on an
Intel i7-13620H laptop with an RTX 4060:

```
CPU   13th Gen Intel(R) Core(TM) i7-13620H
      10 cores (6 performance + 4 efficiency), 16 threads, 63.7 GB memory
      SSE4.2 yes  POPCNT yes  AVX yes  AVX2 yes  FMA yes  BMI1 yes  BMI2 yes  LZCNT yes
      SHA-NI yes  AVX-VNNI yes  AVX-512 no

GPU   Intel(R) UHD Graphics
      integrated, 31.9 GB, Vulkan 1.3, 64-bit floats no  64-bit ints no  16-bit ints yes  8-bit ints yes
      NVIDIA GeForce RTX 4060 Laptop GPU   <- `gpu` blocks run here
      discrete, 7.8 GB, Vulkan 1.3, 64-bit floats yes  64-bit ints yes  16-bit ints yes  8-bit ints yes

What Century does on this machine
  --jit      native x86-64 code, 4 x f64 / 8 x f32 per vector, 16 threads
  dot4       native (AVX-VNNI)
  sha256*    native (SHA-NI)
  gpu do     on NVIDIA GeForce RTX 4060 Laptop GPU
```

The same scan runs automatically before every program. You never need to
configure anything: Century adapts to the machine and says so when it changes
course. **Every fallback computes the same answer; only the speed differs.**

| Situation | What Century does |
|---|---|
| The CPU has AVX2, FMA and BMI2 (any Intel Core from 2013 on, any AMD Ryzen) | `--jit` runs native code. |
| The CPU lacks one of them (an older or budget Pentium, Celeron or Atom) | The program runs on the interpreter instead, with one line on stderr naming what is missing. Same answer, much slower, one thread. |
| The program calls `dot4` and the CPU has no AVX-VNNI (Intel added it in the 12th generation, and many CPUs lack it) | That program runs on the interpreter. Programs that do not call `dot4` stay native. |
| The program calls a `sha256*` builtin and the CPU has no SHA-NI (many Intel CPUs of the 6th to 10th generations) | The same as `dot4`. |
| Several GPUs are present | `gpu` blocks use a discrete GPU over an integrated one. |
| The GPU cannot do 64-bit floats, or 64-, 16- or 8-bit integers (many integrated GPUs have no 64-bit floats) | A `gpu` block that uses that type runs on the CPU threads instead. The others still run on the GPU. |
| No GPU, or no Vulkan driver | Every `gpu` block runs on the CPU threads, at full CPU speed. |

Each change of course is said once, on stderr, for example:

```
century: this CPU has no AVX-VNNI (dot4), so t_dot4 runs on the interpreter (the same answer, more slowly)
century: Intel(R) UHD Graphics cannot compute with 64-bit floats, so a `gpu` block that uses them runs on the CPU
century: no Vulkan driver (vulkan-1.dll not found), so `gpu` blocks run on the CPU
```

**If a program crashes**, Century says why instead of vanishing:

```
century: the program stopped on an access violation, most often an array index past the end.
Run the same function with --ir-run: the interpreter checks every access and says which one failed.
```

Native code does not check array bounds, which is part of why it is fast. The
interpreter checks every access and names the failure, for example
`ir: load outside any allocation`.

---

## 4. The language

### 4.1 Files, comments and blocks

- Source files end in `.cy` and are plain text. A UTF-8 byte-order mark is fine.
- `--` starts a comment that runs to the end of the line. There are no block comments.
- Blocks open with a keyword (`fn`, `if`, `while`, `for`, `match`, `type`,
  `cpu do`, `gpu do`) and close with `end`. Indentation and line breaks are
  free: they are not part of the syntax. Write one statement per line by convention.
- Names are letters, digits and `_`, not starting with a digit. They are case sensitive.
- Declarations can appear in any order. A function may call one defined later,
  and two functions may call each other.

### 4.2 Types

| Type | Meaning |
|---|---|
| `u8 u16 u32 u64` | Unsigned integers. Arithmetic wraps around. |
| `i8 i16 i32 i64` | Signed integers, two's complement. Arithmetic wraps around. |
| `f32 f64` | IEEE floats. |
| `bool` | `true` or `false`. |
| `string` | A text constant (section 4.10). |
| `T[]` | A dynamic array of `T` (section 4.9). |
| `T[N]` | A fixed-length array. Accepted as a type but cannot be created yet: use `T[]`. |
| `(A, B, ...)` | A tuple of two or more values (section 4.11). |
| `map[K, V]` | A hash map (section 4.12). |
| `fn(A, B -> R)` | A function value. `fn(A)` returns nothing. |
| `A \| B \| C` | A union: one value that is one of these types (section 4.15). |
| `simd[T, N]` | A machine vector of N lanes (section 4.19). |
| `Name`, `Name[A, B]` | A declared struct or sum type, possibly generic (sections 4.13 to 4.16). |

`[]` binds tighter than `|`: `u32[] | string` is an array of u32 or a string.
Parentheses group: `(u32 | string)[]`.

The type names `u8` to `f64`, `bool` and `string` are reserved: **you cannot
name a variable `i8` or `u32`**. The words `cpu`, `gpu` and `extern` are
reserved too.

### 4.3 Literals

| Literal | Examples | Notes |
|---|---|---|
| Integer | `0`, `42`, `4000000000` | Decimal only. There are no hex or binary literals and no `_` separators. |
| Float | `1.5`, `0.25`, `1e-9`, `2.5E10` | Needs a digit on both sides of the point: `1.0`, not `1.` or `.5`. |
| Bool | `true`, `false` | |
| String | `"hello"`, `"a\tb\n"` | Escapes: `\n`, `\t`, and a backslash before any other character gives that character (`\"`, `\\`). One line only. |

**A bare integer literal takes the type of whatever it is used with.** In
`n + 1` with `n: u32`, the `1` is a `u32`. A literal never used with anything
typed becomes `i32`. To be explicit, write the conversion: `u32(0)`, `u64(1)`.
Float literals work the same way and become `f64` when alone.

Write big constants through a conversion, such as `u64(2654435761)`. A literal
above 2^31 then keeps its full value.

### 4.4 Bindings: `mut`, and the assignment rule

```
mut x = 5          -- declares a NEW mutable binding
y = 10             -- y is not in scope: declares a NEW immutable binding
x = x + 1          -- x is in scope and mutable: assigns to it
y = 3              -- error: y is immutable
```

- `mut name = e` always declares a fresh binding, even if an outer one has the
  same name. Inner scopes may shadow outer names. Declaring a name twice in the
  same scope is an error.
- `name = e` declares an immutable binding when `name` is new, and assigns when
  `name` is an existing `mut` binding.
- A binding's type comes from its first value and never changes. **There are
  no type annotations on bindings** (`mut x: u32 = 0` does not parse). Use a
  conversion instead: `mut x = u32(0)`.
- Every binding must be given a value when declared.

### 4.5 Functions

```
fn add(a: u32, b: u32) -> u32
    return a + b
end

pub fn exported(n: u64) -> u64       -- `pub`: other files can use it
    return n * u64(2)
end

fn log_nothing(x: u32)               -- no `-> T`: returns nothing
    return                           -- optional
end
```

- Parameters are immutable bindings.
- **Arrays and maps are passed by reference**: a function can change the
  caller's array. **Structs, tuples and numbers are passed by value**: a function
  gets a copy.
- A function may return a tuple or a struct: `fn divmod(a: u32, b: u32) -> (u32, u32)`.
- Recursion works.
- A parameter may carry a range, `fn f(n: u32 in 0..1000)`. That is a promise
  about what callers pass, which `--check-overflow` and the optimiser rely on.

### 4.6 Statements and control flow

```
if x > u32(10) then
    ...
end

if x > u32(10) then
    ...
else
    ...
end

-- there is no `else if`: nest an `if` inside `else`, with its own `end`
if x > u32(10) then
    r = u32(1)
else
    if x > u32(5) then
        r = u32(2)
    else
        r = u32(3)
    end
end

while i < n do
    i = i + u32(1)
end

for x in arr do          -- arrays only; x is each element in turn
    s = s + x
end

return
return e
```

- Conditions must be exactly `bool`. Numbers are not truthy.
- `for` walks an **array** only. It has no ranges and no maps. For a counting
  loop, use `while` with a counter.
- **There is no `break` or `continue`.** Put the exit in the `while` condition:
  `while i < n and not found do`.
- When `for` walks an array of structs, assigning a field of the loop variable
  (`p.x = p.x + p.vx`) writes into the array itself.
- Only a call can stand alone as a statement (also `push` and `store`). A
  built-in that returns a value must be bound: `mut old = atomic_add(h, k, u32(1))`.
- `match` is described in sections 4.14 and 4.15, `gpu do` in 4.20 and
  `cpu do` in 4.21.

### 4.7 Operators

From loosest to tightest:

| Precedence | Operators | Operands |
|---|---|---|
| 1 | `or` | `bool`, short-circuit |
| 2 | `and` | `bool`, short-circuit |
| 3 | `==` `!=` | Any two values of the **same** type |
| 4 | `<` `<=` `>` `>=` | Two numbers of the same type |
| 5 | `\|` | Bitwise or, same integer type |
| 6 | `^` | Bitwise xor, same integer type |
| 7 | `&` | Bitwise and, same integer type |
| 8 | `<<` `>>` | Shifts. The count may be any integer type. `>>` is arithmetic on signed types. |
| 9 | `+` `-` | Same numeric type |
| 10 | `*` `/` `%` | Same numeric type |
| 11 | `not`, `-`, `~` | Unary: logical not on `bool`, negate, flip every bit of an integer |
| 12 | `.` `[]` `()` | Field, index, call |

- **Both sides must already have the same type.** There is no promotion:
  `u32 + u64` is an error. Convert one side: `u64(a) + b`.
- Unlike C, the bitwise operators bind tighter than comparisons:
  `a & u32(1) == u32(1)` means `(a & 1) == 1`.
- Integer `/` and `%` truncate toward zero: `-7 % 4` is `-3`. **Division or
  remainder by zero gives 0** and does not crash.
- `not` binds tighter than `==`, so write `not (a == b)`, or simply `a != b`.
- Strings support `==` and `!=` only.

### 4.8 Conversions

Write the target type as a function: `f64(x)`, `u32(y)`, `i8(z)`.

| From → to | Rule |
|---|---|
| Integer → wider integer | Exact. Signed values are sign-extended. |
| Integer → narrower integer | Keeps the low bits: `u8(305)` is `49`, `i8(200)` is `-56`. |
| Float → integer | Truncates toward zero: `u32(2.7)` is `2`, `i32(-2.7)` is `-2`. |
| Integer → float, `f32` ↔ `f64` | Rounds to nearest. |
| `bool` → integer | `1` or `0`: `u32(a > b)`. Useful for counting without branching. |
| Vector → vector | Lane by lane, keeping the lane count: `f32(v)` turns `simd[i32, 8]` into `simd[f32, 8]`. |

There is no conversion to `bool` or to `string`. Bit-level reinterpretation is
`tobits` and `frombits` (section 5).

### 4.9 Arrays

```
mut a = array[f64](n)          -- n elements, all zero
a[0] = 1.5
x = a[0]
k = len(a)                     -- u32

mut list = array[u32](0)       -- empty, then grow
push(list, u32(7))

mut g = array[f64](rows, cols) -- two dimensions, zeroed, stored row-major
g[i, j] = 1.0
```

- `array[T](n)` allocates `n` zeroed elements. `n` may be any integer type.
  `len` returns `u32`.
- Indexes are integers. **Native code does not check bounds**: an index past the
  end reads garbage or crashes (section 3). `--ir-run` checks every access.
- Any number of dimensions works: `array[T](a, b, c)` then `x[i, j, k]`. Only an
  array created with several dimensions can be indexed with commas.
- Arrays are shared, not copied: after `b = a`, both names refer to the same
  elements. Passing an array to a function lets it change the array.
- Elements may be numbers, `bool`, `simd` vectors, or structs. See section 7
  for the element types native code cannot hold yet.
- Arrays of structs: read and write fields directly, as in `ps[i].x = ps[i].x + 1.0`.
  The compiler chooses the memory layout and may store each field as its own
  array when that reads less memory. `--layout` shows what it decided.

### 4.10 Strings

Strings are **constants**: text written in the source, used as names, map keys,
file paths and arguments to operating-system calls.

```
name = "alice"
if name == "alice" then ... end
mut ages = map[string, u32]()
ages["alice"] = u32(30)
data = readfile("input.bin")
raw = bytes("GET ")            -- the bytes of a string literal, as u8[]
```

Strings cannot be built, joined, sliced or indexed at run time. For text work,
use `u8[]` arrays of bytes: `bytes("...")` gives the bytes of a literal, and
`writefile` writes bytes out.

### 4.11 Tuples

```
t = (u32(3), 2.5)              -- type (u32, f64)
x = t.0                        -- elements by position
y = t.1

fn divmod(a: u32, b: u32) -> (u32, u32)
    return (a / b, a % b)
end
r = divmod(u32(30), u32(7))    -- r.0 is 4, r.1 is 2
```

A tuple can also index a multi-dimensional array: `a[(i, j)]` is `a[i, j]`.

### 4.12 Maps

```
mut m = map[string, u32]()     -- empty
m["one"] = u32(1)
m["one"] = m["one"] + u32(5)
x = m["missing"]               -- a missing key reads as 0 and is not added
k = len(m)                     -- number of entries, u32
```

- Keys must be a number, `bool` or `string`.
- Values must be a number, `bool` or `string` in native code (section 7).
- Maps cannot be iterated, and keys cannot be removed.

### 4.13 Structs

```
type Vec2
    x: f64
    y: f64
end

type Counter
    name: string
    mut hits: u32              -- only `mut` fields can be assigned
end

v = Vec2(x: 1.5, y: 2.0)       -- every field, by name, in any order
mut c = Counter(name: "c", hits: u32(0))
c.hits = c.hits + u32(1)
s = v.x + v.y
```

- Construction names every field exactly once. There are no defaults.
- A field is immutable unless declared `mut`. That includes changing the
  contents of an array held in a field: `g.cells[1] = ...` needs `mut cells: u32[]`.
- Structs are values: `d = c` copies, and a function gets a copy.
- Structs can nest (`b.pos.x`), and a struct can hold arrays, tuples and maps.
- `volatile` on a field (`volatile status: u32`) means every read and write is
  a real memory access that is never cached, merged or reordered. It is for
  memory-mapped hardware registers. A volatile field must be a single scalar,
  and a struct holding one cannot be copied.
- The compiler orders fields for size, not in declaration order. `--layout`
  prints the result.

### 4.14 Sum types and `match`

```
type Shape
    case Circle(r: f64)
    case Rect(w: f64, h: f64)
    case Empty
end

s = Shape.Circle(1.5)                  -- construct a variant, qualified
e = Shape.Empty                        -- no payload, no parentheses

fn area(s: Shape) -> f64
    match s
        case Circle(r) then
            return 3.14159 * r * r
        case Rect(w, h) then           -- bind every payload value, by position
            return w * h
        case Empty then
            return 0.0
    end
end
```

- A type is either a struct (fields) or a sum (`case` lines), never both.
- **Every variant must be handled.** There is no default case, so adding a
  variant later makes every `match` that misses it a compile error.
- Payload names are bound for that arm only.

### 4.15 Unions

A union holds a value of one of several types. You must `match` it before
using it.

```
fn describe(v: u32 | f64 | string) -> u32
    match v
        case u32 k then
            return k
        case f64 d then
            return u32(d)
        case string s then
            return u32(99)
    end
end

x = describe(u32(5)) + describe(2.5) + describe("x")
```

Any value of a member type can be passed where the union is expected. Member
order does not matter: `string | u32` and `u32 | string` are the same type.

### 4.16 Generics

Types and functions take type parameters in square brackets:

```
type Pair[A, B]
    first: A
    second: B
end

type Option[T]
    case Some(value: T)
    case None
end

fn swap[A, B](p: Pair[A, B]) -> Pair[B, A]
    return Pair[B, A](first: p.second, second: p.first)
end

fn unwrapOr[T](o: Option[T], d: T) -> T
    match o
        case Some(value) then
            return value
        case None then
            return d
    end
end

p = Pair[u32, u64](first: u32(1), second: u64(2))
q = swap(p)                                    -- Pair[u64, u32]
a = unwrapOr(Option[u64].Some(u64(40)), u64(1))
```

- A generic type is always written with its arguments, as in `Pair[u32, u64]`.
- A generic function's parameters are worked out from the arguments. You
  cannot write them at the call.
- Inside a generic, arithmetic and comparison on `T` are checked once `T` is
  known. A literal does not convert to `T`: pass the constant in as an argument.

### 4.17 Function values

```
fn twice(a: u32) -> u32
    return a * u32(2)
end

fn apply(f: fn(u32 -> u32), x: u32) -> u32
    return f(x)
end

mut g = twice                  -- a function used as a value
r = apply(g, u32(5))           -- 10
```

A function value can be stored in a binding, passed, returned and called. It
cannot be stored in an array in native code yet (section 7).

### 4.18 Modules, `pub` and constants

**Constants** live at the top level of a file. They have no `mut`, and their
value must be a literal or a conversion of one:

```
LIMIT = 100
SCALE = u64(3)
pub ORIGIN = u64(1000)         -- `pub`: other files can use it
```

**Modules.** `require` loads another file and gives it a name. Only its `pub`
functions, types and constants are visible, through that name:

```
-- geo.cy
pub type Point
    x: u64
    y: u64
end

pub fn manhattan(p: Point) -> u64
    return p.x + p.y
end
```

```
-- main.cy
mut geo = require("geo.cy")

fn far(a: geo.Point, b: geo.Point) -> geo.Point
    if geo.manhattan(a) > geo.manhattan(b) then
        return a
    end
    return b
end

pub fn run(n: u32) -> u64
    p = far(geo.Point(x: u64(n), y: u64(1)), geo.Point(x: u64(2), y: u64(2)))
    return geo.manhattan(p)
end
```

- A path is relative to the file that requires it. A path beginning with `/`
  is relative to the folder of the file you ran.
- Another file's types work everywhere a local type does: in signatures,
  arrays and generics (`geo.Pair[u32, u64]`), and as variants (`geo.Shape.Circle(1.0)`).
- A file required by several others is loaded once. Circular requires are an error.
- `require` may also appear inside a function (`mut m = require("x.cy")`).

### 4.19 Vectors: `simd`

`simd[T, N]` is N lanes of T in one machine register. It must be 128 or 256
bits wide:

| Lane type | Lane counts |
|---|---|
| `f64`, `u64`, `i64` | 2 or 4 |
| `f32`, `u32`, `i32` | 4 or 8 |
| `u16`, `i16` | 8 or 16 |
| `u8`, `i8` | 16 or 32 |

```
v = simd[f64, 4](1.0, 2.0, 3.0, 4.0)   -- one value per lane
z = simd[f64, 4](0.0)                  -- one value: copied into every lane
w = simd[f64, 4](arr, i)               -- load arr[i] .. arr[i+3]
store(arr, i, w)                       -- write them back

x = v * 2.0 + z                        -- operators work lane by lane; a scalar is spread to every lane
third = v[2]                           -- one lane; the index must be a literal
total = hsum(v)                        -- add the lanes together: 10.0

mask = v > 2.5                         -- a comparison gives a mask: simd[u64, 4], all ones or all zeros per lane
big = select(mask, v, z)               -- per lane: v where the mask is set, z elsewhere
rev = shuffle(v, 3, 2, 1, 0)           -- reorder lanes
```

- Every arithmetic, bitwise and shift operator works lane by lane. There is
  no `%` on vectors, and `and`/`or` do not apply: use `&` and `|` on masks.
- Conversions work lane by lane (section 4.8).
- More vector built-ins are listed in section 5: `hmin`, `hmax`, `hand`, `hor`,
  `hxor`, `lookup`, `mulhi`, `dot2`, `dot4`, `fma`, `popcount` and others.
- You rarely need `simd` for speed. The compiler vectorises ordinary loops by
  itself (section 6). Use it when you want a particular instruction.

### 4.20 Parallel loops on the GPU: `gpu do`

Mark a loop nest whose iterations are independent, and it runs on the GPU:

```
pub fn scale(n: u32) -> u64
    mut a = array[f32](n)
    gpu do
        mut i = u32(0)
        while i < n do
            a[i] = f32(i) * f32(2.0)
            i = i + u32(1)
        end
    end
    mut s = u64(0)
    for x in a do
        s = s + u64(x)
    end
    return s
end
```

- The block holds a loop nest written with counters, as above. Up to three
  nested loops map onto the GPU's grid. A deeper nest, or a block that uses
  more than 32 arrays, runs on the CPU threads instead. `--emit-spv <dir>`
  lists which blocks became GPU kernels and why the others did not:

  ```
  deep.cy:3: note: this `gpu` block runs on the CPU - a nest more than three deep, which needs a linearised grid
  ```
- A nested loop joins the grid only when the stores tell its iterations apart.
  In `a[i] = a[i] + src[i*w + j]` over `i` and `j`, every `j` adds into the same
  `a[i]`, so the grid takes `i` alone and each thread runs the `j` loop itself.
  `CY_GPU_WHY=1` says when a grid stops short.
- **The compiler proves the iterations independent or refuses**, naming the
  reason. Nothing is taken on trust:

  ```
  refuse.cy:3:0: error: this `gpu` block cannot be run wide: two iterations could write the same element
       3 |     gpu do
         | ^
         = help: two accesses to one array are a fixed distance apart and that distance is larger than what one iteration advances by
  ```

- Each iteration may read anything and write its own elements. Shared counters
  and histograms use `atomic_add` (section 5), which may target any element:

  ```
  gpu do
      mut i = u32(0)
      while i < n do
          mut old = atomic_add(hist, i % u32(16), u32(1))
          i = i + u32(1)
      end
  end
  ```

- A function called inside a `gpu` block runs on the GPU too, but **only if
  every argument is a number or a bool**. A helper that takes an array makes
  the whole block run on the CPU instead (still correct, just not on the GPU).
  Read the array elements inside the block and pass the values.
- **Only what changed crosses to the GPU.** When the CPU writes part of an
  array that lives on the GPU, only that part is sent before the next kernel.
  This works for one element (`a[k] = v`) and for a stretch written by a counted
  loop (`while j < hi do a[j] = ...; j = j + u32(1) end`, stores at `j` or
  `j + c`). Two hundred one-element updates of a 64 MB array, each followed by
  a kernel launch, took 44 ms instead of 2.3 s. Other write patterns send the
  whole array, as before.
- Data moves between CPU and GPU automatically, and only when needed: arrays
  that several kernels use stay on the GPU between them.
- The answer is bit-for-bit what the same loop gives on the CPU. `f32` division
  and square root are computed exactly on the GPU too, unless you pass
  `--gpu-approx`. A GPU's own divide is only accurate to a few units in the
  last place, so the exact one is built from integer steps around it. It
  matches the CPU on every input, NaN, infinities and denormals included, and
  needs no `f64`. A loop of 64 divides per element ran 4.2 times faster than
  the `f64` route used before. Square root still goes through `f64`, which a
  GeForce card runs at 1/64 speed: use `--gpu-approx` where a last-bit
  difference is acceptable.
- With no usable GPU, the block runs on all CPU threads (section 3).
  `--no-gpu` forces that; `--no-parallel` runs everything on one thread.

**Two blocks at once**: `gpu join` runs its arms at the same time, each of them
in parallel. No two arms may touch the same array.

```
gpu join(
    async do
        mut i = u32(0)
        while i < n do
            a[i] = i
            i = i + u32(1)
        end
    end,
    async do
        mut j = u32(0)
        while j < n do
            b[j] = j * u32(2)
            j = j + u32(1)
        end
    end
)
```

**Groups of threads and on-chip memory: `shared`.** A GPU runs its threads in
groups of up to 1024 that share a small memory on the chip: tens of kilobytes a
group, close to the speed of registers, where an ordinary array lives in the
card's main memory. Declaring a `shared` array in the body of a `gpu` block's
outer loop makes **each outer iteration one group**, and the arrays it declares
that group's on-chip memory:

```
-- b[i] = a[i-1] + a[i] + a[i+1], n a multiple of 256: each group reads its 256
-- elements and the one on either side ONCE, then every thread reads three
-- of them from the chip
gpu do
    mut g = u32(0)
    while g < n / u32(256) do
        shared t = array[f32](258)
        mut l = u32(0)
        while l < u32(256) do                     -- phase 1: an element a thread
            t[l + u32(1)] = a[g * u32(256) + l]
            l = l + u32(1)
        end
        l = u32(0)
        while l < u32(2) do                       -- phase 2: two threads, the edges
            mut v = f32(0.0)
            if l == u32(0) then
                if g > u32(0) then
                    v = a[g * u32(256) - u32(1)]
                end
            else
                if g + u32(1) < n / u32(256) then
                    v = a[g * u32(256) + u32(256)]
                end
            end
            t[l * u32(257)] = v
            l = l + u32(1)
        end
        l = u32(0)
        while l < u32(256) do                     -- phase 3: the neighbours
            b[g * u32(256) + l] = t[l] + t[l + u32(1)] + t[l + u32(2)]
            l = l + u32(1)
        end
        g = g + u32(1)
    end
end
```

- The outer loop's body holds `shared` arrays, statements every thread of the
  group runs alike (declarations, `if`, a loop over tiles), and **phases**:
  `l = u32(0)` / `while l < u32(L) do ... l = l + u32(1) end`, `L` a literal of
  at most 1024. Each thread takes one iteration of a phase, and **every thread
  finishes a phase before any starts the next**, so a phase sees everything the
  one before it wrote.
- `shared t = array[T](n)`: `n` a literal, `T` one of `u32`, `i32`, `f32`,
  `u64`, `i64`, `f64`, at most 32 KB an array and 48 KB a group. It starts at
  zero.
- **A phase is proved race-free or refused.** In a phase each thread writes only
  its own elements - `t[base + l]`, or `t[l * K + i]` with `i` the counter of a
  loop `i = u32(0)` / `while i < u32(K)` inside the phase, which gives each
  thread its own `K` - and every access in that phase to an array it writes
  uses the same subscript. What other threads wrote is there in the next
  phase. An array declared inside a phase belongs to its thread and lives in
  registers.
- Statements between phases may compute but not write an array: every thread
  runs them, so each would make the store. A value written once goes in a
  phase of one thread, `while l < u32(1)`.
- With no GPU, or `--no-gpu`, the block runs as the nested loops it is written
  as, with the same answer bit for bit.

What it buys: `C = A·B` for 2048 x 2048 `f32` matrices, each thread holding a
4 x 4 block of `C` in a private array and running through 64 x 16 tiles of `A`
and `B` staged in shared memory, takes 6.4 ms on an RTX 4060 Laptop GPU (2.7
TFLOPS, each sum exact and in the order written) against 28.8 ms with one thread
an element of `C`: 4.5 times faster, the same bits. A phase that could race is
refused:

```
race.cy:3:0: error: this `gpu` block cannot be run wide: a phase reads an array at one element and writes it at another
       = help: within a phase each lane touches its own element of what it writes; other lanes' elements are there in the NEXT phase, after the barrier
```

### 4.21 Parallel loops on the CPU: `cpu do`

`cpu do` is the same idea for the processor: the loop nest inside runs on
**every CPU thread at once**, never on the GPU.

```
pub fn heavy(n: u32) -> f64
    mut a = array[f64](n)
    cpu do
        mut i = u32(0)
        while i < n do
            mut x = f64(i) * 0.000001
            mut k = u32(0)
            while k < u32(64) do          -- an ordinary loop inside each iteration
                x = sqrt(x * x + 1.0)
                k = k + u32(1)
            end
            a[i] = x
            i = i + u32(1)
        end
    end
    return a[n / u32(2)] + a[n - u32(1)]
end
```

On the 16-thread laptop of section 3, `heavy(4000000)` takes 0.075 s on all
threads and 0.662 s with `CY_THREADS=1` (best of five warm runs): 8.8 times
faster, the same answer.

- The proof is the one `gpu do` gets: the outer loop is a counted `while`,
  and **the compiler proves every iteration independent or refuses the
  program**, so a `cpu do` block can never race. (The GPU's own limits, such as
  at most three nested loops, do not apply.) Here each iteration reads what the
  one before it wrote, so it cannot run wide:

  ```
  -- prefix.cy
  pub fn prefix(n: u32) -> u32
      mut a = array[u32](n)
      cpu do
          mut i = u32(1)
          while i < n do
              a[i] = a[i - u32(1)] + i
              i = i + u32(1)
          end
      end
      return a[n - u32(1)]
  end
  ```

  ```
  prefix.cy:4:0: error: this `cpu` block cannot be run wide: an array is read at one element and written at another
       4 |     cpu do
         | ^
         = help: every access to an array written here has to use the same subscript, or one iteration could read what another is writing
  ```
- Inside an iteration you can use inner loops, local variables, `if`, and
  calls to functions that only compute (no `extern` calls, `push`, maps, files
  or `clock()`: those happen in an order, and the iterations have none).
- Struct values work as they do anywhere else. A struct from outside the
  loop can be read, a new one can be built in an iteration, and either can be
  passed to a helper. **An array held in a struct can be written from the
  loop** (`g.cells[i] = x`) when the struct was declared in this function from
  a literal that gives that field a fresh `array[T](n)`, and neither the struct
  nor the field is assigned again: it is then an array of its own, and the
  rules above apply to it. Otherwise the compiler refuses and says why - copy
  the array into a local first. A `gpu` block cannot index a field at all: put
  the block in a function that takes the array and call it with the field,
  `kern(g.cells, n)`. Reading or writing `g.cells` on the CPU afterwards sees
  what the kernel did, and the kernel sees what the CPU wrote.
- A `cpu do` loop with too little work to pay for waking the threads (about
  half a millisecond's worth) runs on the calling thread instead.
  `CY_PAR_COUNT=1` shows when that happens (section 9).
- **When to use it instead of `gpu do`:** when the data already lives on the CPU
  and is used there next, when each iteration does branchy or irregular work,
  when it needs `f64` on a GPU that is slow at it, or when the loop is too
  small to pay for moving data to the GPU and back.
- **Why mark it at all?** The compiler spreads loops it can prove independent
  across the threads by itself (section 6.4). `cpu do` turns "please" into
  "must": if the proof fails you get the error and its reason instead of a
  loop that quietly runs on one thread.
- `CY_THREADS=N` limits the threads; `--no-parallel` runs it on one.

### 4.22 Calling the operating system: `extern`

`extern` declares a function that lives in a Windows DLL, so a program can call
the operating system or any C library directly:

```
extern "kernel32.dll" fn GetTickCount64() -> u64
extern "kernel32.dll" fn Sleep(ms: u32)
extern "kernel32.dll" fn GetCurrentProcessId() -> u32
extern "kernel32.dll" fn GetEnvironmentVariableA(name: string, buf: u8[], size: u32) -> u32
extern "user32.dll" fn MessageBoxA(owner: u64, text: string, title: string, kind: u32) -> i32
extern "msvcrt.dll" fn pow(x: f64, y: f64) -> f64

pub fn demo() -> u32
    Sleep(u32(100))                                    -- a statement: returns nothing
    mut buf = array[u8](260)
    n = GetEnvironmentVariableA("PATH", buf, u32(260)) -- the DLL writes into buf
    r = MessageBoxA(u64(0), "Hello from Century", "Century", u32(0))
    return n
end
```

- The declaration is `extern "library.dll" fn name(parameters) -> result`, at
  the top level of a file, with no body. It is called like any other function.
- The compiler finds the function **when it compiles the program**, so a
  misspelt name is an error at once, not a crash later:

  ```
  ffibad.cy:1:1: error: cannot find `GetTickCount65` in `kernel32.dll`
       1 | extern "kernel32.dll" fn GetTickCount65() -> u64
         | ^
         = help: check the spelling (names are case-sensitive, and most Windows text functions end in A or W) and that the DLL is on this machine
  ```
- Calls use the Windows x64 calling convention, the one every Windows DLL uses,
  with any number of arguments.

How Century types reach C:

| Century | C | Notes |
|---|---|---|
| `bool` | `int` / `BOOL` | As a result, any non-zero value is `true`. A C function that returns a one-byte `bool` should be declared `-> u8` instead. |
| `u8 u16 u32 u64`, `i8 i16 i32 i64` | `uint8_t` ... `int64_t` | `DWORD` is `u32`; `int` and `LONG` are `i32`; `size_t` is `u64`. |
| `f32`, `f64` | `float`, `double` | |
| `string` | `const char*` | A NUL-terminated copy of the text. Use the `A` form of a Windows function (`MessageBoxA`). |
| `T[]` | `T*` | The address of the first element. The C side may read and write it, but **not past `len(a)`**: make the array big enough first. |
| a pointer or a handle (`HANDLE`, `HWND`, `void*`) | `u64` | Pass `u64(0)` for NULL. |

- A Windows function that returns `BOOL` is safest declared `-> i32`.
- To read a C struct, pass a `u8[]` or `u32[]` big enough to hold it and pick
  the fields out by offset.
- An `extern` call can do anything, in an order, so it cannot appear inside a
  `cpu do` or `gpu do` block, and a loop that contains one runs on one thread.
  In a block it is refused:

  ```
  ffiloop.cy:5:0: error: this `cpu` block cannot be run wide: the body does something whose order cannot be reasoned about
       5 |     cpu do
         | ^
         = help: only arithmetic, array access and calls to functions that only compute can run wide - no `extern` calls, no `push`, no maps, no files, no `clock()`
  ```

  Call the DLL before or after the parallel loop, once on a whole array
  rather than once per element.
- Arrays shared with `gpu do` blocks stay consistent: an array the GPU wrote
  is fetched before the call, and anything the DLL wrote reaches the GPU next time.
- `extern` runs in native code: `--jit` and built programs (section 2.5). The
  interpreter (`--ir-run`) cannot call into DLLs and stops with a message
  saying so. That includes a CPU too old for native code (section 3), where
  `--jit` itself falls back to the interpreter.
- A built program looks each `extern` function up again when it starts, by
  library and name. If the DLL or the name is not on that machine, it stops
  before running anything: `prog.exe: cannot find `F` in `lib.dll` on this machine`.
- There are no callbacks: a C function cannot call back into Century.

### 4.23 Files

```
data = readfile("input.bin")            -- u8[]; empty if the file cannot be opened
wrote = writefile("out.bin", data)      -- u32: bytes written, 0 on failure
raw = bytes("header:")                  -- the bytes of a string literal
```

The path is a string, or a `u8[]` holding the path's bytes, which is how a
program names a file it builds at run time:

```
mut name = array[u8](0)
for c in bytes("out/run") do
    push(name, c)
end
push(name, u8(u32(48) + k))               -- out/run3 for k = 3
wrote = writefile(name, data)
```

A path that ends in `/` reads the folder instead: `readfile("images/")` gives
the names in it, sorted, one per line, with a `/` after each folder's name, or
an empty array if there is no such folder. That is how a program finds the
files in a folder its user names.

Relative paths are relative to the folder you ran `century` from. Files are
whole-file only: one call reads or writes everything.

### 4.24 Time: `clock()`

`clock()` returns an `f64`: the seconds since the program started, from the
processor's high-resolution counter (well under a microsecond per tick). It
never goes backwards. Use it to time code from inside the program:

```
pub fn timed(n: u32) -> f64
    t0 = clock()
    x = heavy(n)
    return clock() - t0          -- seconds
end
```

`clock()` is for measuring intervals, not for the date (for that, call the
operating system through `extern`). A `clock()` call is never removed, merged
with another, or moved past the reads and writes around it, so the work between
two calls is what gets timed. Section 6.1 says how to time well.

### 4.25 Tolerances: `~`

```
mut acc ~ 1e-6 = 0.0
mut i = u32(0)
while i < len(a) do
    acc = acc + a[i] * a[i]
    i = i + u32(1)
end
```

`~ 1e-6` lets the compiler add into `acc` in a different order: several
vector accumulators side by side, folded together in a fixed order at the end.
The number is how far the result may move, relative to the sum of the
magnitudes of what is added. `--jit` and `--ir-run` use the same order, so the
result is still reproducible.

- It applies to a sum in a counted `while` loop. **A `for x in a` loop is
  not rewritten**: write the sum with an index, as above.
- The faster order is used only when even its worst case fits the bound: when
  the loop's length times the precision of the type (2^-53 for `f64`, 2^-24 for
  `f32`) is at most the tolerance. Otherwise the loop runs exactly as written.
  The length is checked each time the loop starts (section 6.3 has the numbers).
- `~` may also be put on an `f32`/`f64` array or an array of all-float structs.
  Without `~`, floating-point arithmetic happens in exactly the order written.

---

## 5. Built-in functions

A local binding or function with the same name hides a built-in.

**Arrays, maps, files and time**

| Built-in | Result | Meaning |
|---|---|---|
| `len(a)` | `u32` | Elements in an array, or entries in a map. |
| `push(a, v)` | statement | Appends `v` to the dynamic array `a`. |
| `store(a, i, v)` | statement | Writes the vector `v` over `a[i]` .. `a[i+N-1]`. |
| `readfile(path)` | `u8[]` | The whole file, or an empty array if it cannot be opened. |
| `writefile(path, data)` | `u32` | Writes a `u8[]` and returns the bytes written. |
| `bytes("text")` | `u8[]` | The bytes of a string literal, which must be written in place. |
| `atomic_add(a, i, v)` | `u32` | Adds `v` to `a[i]` indivisibly and returns the old value. `a` is a `u32[]`. Safe inside `cpu` and `gpu` blocks, which run wide with it - also beside ordinary stores to other arrays (a `lock xadd` on the CPU). |
| `clock()` | `f64` | Seconds since the program started (section 4.24). |

**Maths.** These work on numbers and, lane by lane, on vectors.

| Built-in | Meaning |
|---|---|
| `sqrt(x)` | Square root. An integer literal argument is taken as `f64`. |
| `abs(x)` | Absolute value. |
| `min(a, b)`, `max(a, b)` | Both arguments of the same type. A bare literal takes the other argument's type, as with operators. |
| `floor(x)`, `ceil(x)`, `trunc(x)` | Round down, up, toward zero. Floats. |
| `round(x)` | Round to nearest, **ties to even**: `round(2.5)` is `2.0`. |
| `fma(a, b, c)` | `a * b + c` with a single rounding. Floats. |

**Bits.** These work on integers and, lane by lane, on integer vectors.

| Built-in | Meaning |
|---|---|
| `popcount(x)` | Number of 1 bits. |
| `clz(x)`, `ctz(x)` | Leading and trailing zero bits. For `0`, the bit width. |
| `rotl(x, k)`, `rotr(x, k)` | Rotate left or right by `k`, taken modulo the width. |
| `tobits(f)` | The bit pattern of an `f32` (as `u32`) or an `f64` (as `u64`). |
| `frombits(i)` | The float with that bit pattern: `u32`/`i32` give `f32`, `u64`/`i64` give `f64`. |

**Vectors.** `v` is a `simd[...]` value.

| Built-in | Meaning |
|---|---|
| `hsum(v)`, `hmin(v)`, `hmax(v)` | Sum, minimum or maximum of all lanes. |
| `hand(v)`, `hor(v)`, `hxor(v)` | Bitwise and, or, xor of all lanes (integer lanes). |
| `select(mask, a, b)` | Per lane, `a` where the mask lane is all ones and `b` where it is zero. The mask comes from a vector comparison. |
| `shuffle(v, i0, i1, ...)` | Reorders lanes, one literal index per lane. |
| `shuffle(a, b, i0, ...)` | Picks lanes from two vectors: `a`'s are numbered `0..N-1`, `b`'s `N..2N-1`. |
| `lookup(table, idx)` | Byte table lookup on `simd[u8, 16 or 32]`: 16 entries per 128-bit half, and an index byte with its top bit set gives 0. |
| `mulhi(a, b)` | The high 32 bits of each `u32` lane product. |
| `dot2(a, b, acc)` | Each `i32` lane of `acc` plus two `i16 × i16` products. `a` and `b` have twice the lanes of `acc`. |
| `dot4(a, b, acc)` | Each `i32` lane of `acc` plus four `u8 × i8` products. `a` is `simd[u8, 4N]` or `simd[u32, N]` and `b` is `simd[i8, 4N]` or `simd[u32, N]`. Native only with AVX-VNNI (section 3). |
| `sha256rnds2(a, b, wk)`, `sha256msg1(a, b, c)`, `sha256msg2(a, b, c)` | The x86 SHA-256 steps on `simd[u32, 4]`. Native only with SHA-NI (section 3). |

**Files and modules**

| Built-in | Meaning |
|---|---|
| `require("path.cy")` | Loads another file as a module (section 4.18). |

---

## 6. Making it fast

Century compiles every program straight to native x86-64 code, with the whole
program visible at once: it inlines across functions and files, vectorises
loops with AVX2, chooses the memory layout of your structs, spreads independent
loops over every thread, and sends `gpu do` blocks to the GPU. Most of the
speed comes for free. This section is about the rest: how to write code the
compiler can make as fast as the machine allows, and how to prove it.

### 6.1 Measure first, and measure properly

- **Time from inside with `clock()`** (section 4.24), around exactly the code
  you care about.
- **Warm up, then take the best of several runs.** The first run of anything
  pays one-off costs: the operating system handing over fresh memory pages,
  threads starting, the GPU waking from a low-power state. Run the code once
  first, then time three to nine runs and keep the fastest (or the median).
- **Do not let the work disappear.** A result nothing uses may be computed
  less, or not at all. Return something that depends on all of it, a sum or a
  few elements.
- **Compare like with like.** When racing C++, give both the same algorithm,
  the same data and the same machine; build the C++ with `-O3 -march=native`;
  check the two answers agree; and alternate the runs (Century, C++, Century,
  C++...) rather than running one after the other, so that heat and other
  programs affect both the same.
- **Find the hot spot** with `CY_PROFILE=1`: after a `--jit` run it prints the
  24 most executed places in the program by function and line.
- **Check correctness separately**: run small inputs with `--ir-run`, which
  checks every array access, then the big ones with `--jit`.

### 6.2 Write loops the compiler can vectorise

The vectoriser turns a simple loop into AVX2 code that handles 4 `f64`/`u64`,
8 `f32`/`u32`, 16 `u16` or 32 `u8` values per instruction. **The widest type in
the loop sets the count**: one `f64` or `u64` value in an otherwise `f32` loop
halves it. It needs:

- **A counted loop**: `while i < n do ... i = i + u32(1) end`, with `n` not
  changing inside the loop.
- **Arrays read and written in order**: `a[i]`, `b[i + 1]`. For a 2-D array,
  the last index should be the one the inner loop counts (`g[i, j]` with `j`
  inner), because rows are stored one after another.
- **Small `if`s are fine; long branches are not.** These forms vectorise:
  - an element-wise minimum or maximum: `if x[i] > y[i] then z[i] = x[i] else
    z[i] = y[i] end`, or `v = y[i]; if x[i] > v then v = x[i] end; z[i] = v`;
  - a clamp: `if v < lo then v = lo end; if v > hi then v = hi end`;
  - a conditional sum or count, `if a[k] > t then total = total + a[k]; hits =
    hits + u32(1) end`: 14 times faster than the branch on 70,000 elements.

  The comparison must be strict (`>` or `<`). The result is then exactly
  `max`/`min`, NaNs and signed zeros included; `>=` is not the same function
  and keeps its branch. Anything longer, turn into arithmetic:
  `count = count + u32(x > t)` instead of `if x > t then count = count + 1 end`.
  A running maximum or minimum, `if a[i] > m then m = a[i] end` with `m`
  carried from one iteration to the next, vectorises as well and still gives
  exactly the scalar answer - the first element to reach the maximum, never a
  NaN: 2.9 times faster over a million `f32`, 3.3 times over `i32`. A loop the
  vectoriser cannot take keeps the branch, which predicts well.
- **Constant stores do not get in the way.** `a[i] = 0.0` next to real work
  (`b[i] = x[i] * 2.0`) vectorises with it. A loop that only fills is limited
  by memory bandwidth whatever is done to it.
- **The narrowest type that is correct.** A vector register holds twice as
  many `f32` as `f64` and twice as many `u32` as `u64`, so the narrower type is
  up to twice the work per instruction. Use `f64` where the precision matters
  and `f32` where it does not.
- **No conversions between widths in the hot loop**: keep a loop's arithmetic
  in one type. Count with `u32`. The conversions that do occur vectorise and
  give the scalar answer for every value: `u32`/`i32` to and from `f32`, `f32`
  to and from `f64`, `f64` to `i32`/`u32` (out-of-range values included),
  integer widening, and `u64` to `u32`. That last one is what lets a division
  by a constant go eight wide: `x % u32(100003)` runs 2.6 times faster than
  before.

When you want one particular instruction, `simd[T, N]` (section 4.19) writes
the vector code by hand.

### 6.3 Floating-point sums: allow reordering with `~`

A floating-point sum without `~` is computed in **exactly the order written**,
one addition after another, because changing the order changes the last bits
of the answer. That is correct, and slow: each addition waits for the one
before it. Declare how much reordering error you accept (section 4.25), and
the compiler keeps sixteen `f64` (or thirty-two `f32`) partial sums going at
once:

```
mut acc ~ 1e-6 = 0.0             -- any order, within 1e-6
mut i = u32(0)
while i < len(a) do              -- a counted loop: `for x in a` is not rewritten
    acc = acc + a[i] * a[i]
    i = i + u32(1)
end
```

On the laptop of section 3, this loop over a million `f64` values takes
0.43 ms in source order and 0.15 ms with the tolerance (best of five warm
runs): 2.9 times faster. The same sum written as `for x in a` stays at 0.43 ms.

The bound is a worst case, so it decides how long a loop may be and still take
the fast path:

| Accumulator | Tolerance | Fast path for loops up to |
|---|---|---|
| `f64` | `~ 1e-9` | 9 million iterations |
| `f64` | `~ 1e-6` or more | any length |
| `f32` | `~ 0.001` | 16,777 iterations |
| `f32` | `~ 0.1` | 1.6 million iterations |

A longer loop silently runs in source order. For long sums of `f32` data, add
into an `f64` accumulator (`acc = acc + f64(x)`) with a tolerance like `1e-9`.
`CY_REASSOC_REPORT=1` prints, while compiling, each sum that was rewritten and
its length limit (`reassoc: guarded at n <= 9007199 for tolerance 1e-09`).

Integer sums need nothing: integer addition gives the same result in any order.

### 6.4 Use every core: automatic parallelism, `cpu do`, `gpu do`

- **Automatic.** Every loop the compiler can prove independent is spread over
  all CPU threads, provided it has enough work to be worth it. Nothing to write.
  `CY_PAR_WHY=1` lists, while compiling, each loop proved independent and
  whether it became a parallel region (and why not). `CY_PAR_COUNT=1` reports
  after the run how often those regions ran wide and how often they were run
  on one thread for having too little work.
- **`cpu do` (section 4.21)** demands it: the loop runs on every thread or the
  program is refused with the reason. Use it on every loop you expect to be
  parallel, so a later change that breaks the independence is an error and not
  a silent slowdown.
- **`gpu do` (section 4.20)** sends the loop to the GPU. It wins when there is
  a lot of arithmetic per element, when the data can stay on the GPU across
  several kernels, and when the work is regular (every iteration does the same
  thing). It loses when the data comes straight back to the CPU after one
  cheap pass: the transfer then costs more than the computing.
- **Make parallel loops independent by design.** Each iteration writes only
  its own elements. A shared counter or histogram uses `atomic_add`. A sum is
  best written as a partial result per iteration into an array, then added up.
- **Parallelise the outer loop.** Waking the threads costs tens of
  microseconds, so one wide region around a big nest beats a wide inner loop
  entered a million times. Put `cpu do` around the outermost loop whose
  iterations are independent.
- **The hybrid CPU trap.** Many recent Intel CPUs mix fast performance cores
  and slower efficiency cores (section 3 shows how many of each). The loop is
  cut into more pieces than there are threads and the pieces are handed out as
  threads come free, so the fast cores take more of them. Plenty of iterations
  keep that working well.
- **Too little work stays on one thread.** A region whose estimated work is
  under about half a millisecond runs on the calling thread. `CY_PAR_COUNT=1`
  prints the biggest one turned down; if you know it is worth spreading,
  `CY_MIN_PAR_WORK` lowers the bar (section 9).

### 6.5 Memory: allocate once, reuse, go in order

- **Allocate outside hot loops.** `array[T](n)` gives zeroed memory, and the
  first touch of each fresh page costs the operating system time. Make your
  arrays once and reuse them between steps.
- **Memory comes back by itself** when a function returns, and at the end of
  every pass of a loop that keeps nothing it allocated (it puts no array into a
  variable declared outside the loop, pushes into no array made before it, and
  hands nothing it made to a function that keeps it). A loop that makes an 8 MB
  array each pass holds 8 MB, not 8 MB per pass. `CY_SCOPE_REPORT=1` says which
  functions and loops give their memory back, and what keeps it when one does
  not.
- **`push` in a loop** grows the array as it goes. When the final size is
  known, allocate that size and write by index.
- **Go through memory in order.** Sequential access is many times faster
  than jumping around: the processor fetches ahead. Lay out 2-D data so the
  inner loop runs along a row.
- **Arrays of structs.** The compiler may store each field of `array[Particle]`
  as its own array, so a loop that reads two fields does not drag the others
  through the cache. `--layout` shows what it chose and why. Keep the fields a
  hot loop needs in the same struct.
- **Smaller is faster when memory-bound.** If a loop streams through more data
  than the caches hold, halving the element size (`f32` for `f64`, `u16` for
  `u32`) can nearly halve its time.

### 6.6 The GPU: keep data there, launch big

- **Keep arrays on the GPU.** Data moves only when needed: if one `gpu do`
  block writes an array and the next reads it, it never leaves the GPU. Reading
  that array on the CPU in between (even one element) brings all of it back.
  Do the CPU-side work after the GPU-side chain, not in the middle. Writing
  part of a GPU array from the CPU is cheap: only the changed element or
  stretch goes back (section 4.20).
- **Launch big.** Each `gpu do` block costs a launch (microseconds). Put
  enough work in each one: millions of iterations, not thousands.
- **The GPU is used only where it is faster.** A `gpu do` block is proved
  independent, so its iterations can also run on the CPU's threads. Each kernel
  is timed on both sides, with every transfer it causes counted, and its calls
  go to the faster one; the other side is tried again now and then. A kernel
  whose cost is the kernel itself, not the copying around it, is never moved.
  `CY_GPU_WHY=1` reports each move, `CY_GPU_STATS=1` shows the calls a kernel
  made on the CPU, and `CY_GPU_ROUTE=gpu` or `=cpu` fixes the choice.
- **Zeros are free to send.** A fresh array is zeros, and zeros are filled in
  on the GPU instead of being copied across, so an output array a kernel fills
  costs nothing to set up. Uploads overlap the copy into the transfer buffer
  with the transfer itself.
- **`f32` on consumer GPUs.** Gaming GPUs compute `f64` 16 to 64 times slower
  than `f32` (the RTX 4060 of section 3: 64 times). Use `f32` in `gpu do`
  blocks where the precision allows.
- **`--gpu-approx`** lets the GPU use its own fast `f32` square root and
  division (the last bit can differ from the CPU). Exact division is fast
  already (section 4.20); exact square root is the slow one.
- **Matrix products on the tensor cores**: `tcgemm(a, b, c, m, n, k, mode)`
  adds `a` (m x k) times `b` (n x k) transposed into `c` (m x n), all `f32[]`.
  It returns `u32(1)` when the tensor cores did it and `u32(0)` when it ran on
  the CPU (exact `f64` sums). On an NVIDIA card it goes through the CUDA
  driver; elsewhere modes 0 and 1 use Vulkan, and the rest run on the CPU.

  | mode | inputs | sums | use | RTX 4060 Laptop, 8192^3 |
  |---|---|---|---|---|
  | 0 | `f16` | `f32` | general | 30 TFLOPS |
  | 1 | `f16` hi + lo split | `f32` | close to `f32` accuracy (about 1e-5) | 10 TFLOPS of `f32` work |
  | 2 | FP8 e4m3 | `f32` | inference, screening | 60 TFLOPS |
  | 3 | `int8` | `int32` | inference | 107 TOPS |
  | 4 | `f16` | `f16`, in blocks of 128 | screening | 43 TFLOPS |
  | 5 | FP8 | `f16` | screening (a CUDA 12.8 driver; before that it runs as mode 2, summing in `f32`) | - |
  | 6 | `int8`, `a` 2:4 sparse | `int32` | pruned weights | 168 TOPS |
  | 7 | FP8, `a` 2:4 sparse | `f32` | pruned weights | 108 TFLOPS |

  Each input is scaled into its format's range first. Modes 6 and 7 keep the
  two largest values of every four along `k` in `a` (exact when `a` is 2:4
  sparse already) and count the work as NVIDIA does, as if `a` were dense.
  `century --cudatc` measures every mode on your card and checks each
  against `f64`.
- **Helpers take numbers.** A function called inside a `gpu do` block must take
  only numbers or bools; one that takes an array makes the block run on the
  CPU (section 4.20). `CY_GPU_WHY=1` says when that happens.
- **See where the time went** with `CY_GPU_STATS=1` (uploads, downloads, launches
  and a line per kernel), adding `CY_GPU_SYNC=1` to time each kernel on its own.
- **One GPU program at a time is best.** Two programs share the GPU's memory,
  and each budgets for most of it. A buffer that will not fit makes that kernel
  run on the CPU (`CY_GPU_WHY=1` says so) rather than crash, but a driver reset
  stops both programs.

### 6.7 Functions, branches and arithmetic

- **Small functions cost nothing**: the compiler inlines them, across files
  too. Split code into functions freely.
- **Function values** (`fn(...)` stored in a binding and called) cannot be
  inlined. Keep them out of hot loops.
- **Branch on what is predictable.** A branch that almost always goes the same
  way is nearly free; one that goes either way at random costs a pipeline flush
  each time it guesses wrong. For those, compute both sides and pick with
  arithmetic or `select`.
- **Divide unsigned.** A divide instruction costs 20 to 40 cycles. Unsigned
  division and remainder by a constant become a multiply and a shift (about
  5), and so does `u32` division by a value that does not change inside the
  loop: the multiplier is worked out once, before the loop. A power of two
  becomes a shift or a mask. Signed division keeps the slow instruction.
- **Bit tricks are single instructions**: `popcount`, `clz`, `ctz`, `rotl`,
  `rotr`, `mulhi`.
- **`fma(a, b, c)`** is one instruction with one rounding. `--fma` makes every
  `a * b + c` on floats one (slightly different last bits, faster).
- **Ranges help the optimiser.** `fn f(n: u32 in 0..1000)` tells the compiler
  what callers pass; it can then drop work it would otherwise have to do.

### 6.8 `extern` calls

An `extern` call (section 4.22) costs a function call into the DLL, and a loop
containing one runs on one thread and cannot be vectorised. Call the DLL once
for a whole array instead of once per element, and keep `extern` calls out of
the inner loops.

### 6.9 Racing C++

What Century does that a C++ compiler does not do by default:

- **It compiles on the machine that runs it.** It reads the CPU first
  (section 3) and uses the instructions that CPU has, with no flags to set and
  no "build for the oldest CPU" penalty.
- **The whole program is one unit.** Calls across files inline like calls
  within one, with no link-time optimisation to set up.
- **Parallel loops are proved, not trusted.** OpenMP runs whatever a pragma
  marks, races included. Century spreads loops it proves independent by itself,
  and `cpu do` refuses a loop that is not.
- **Division by a value known only at run time** becomes a multiply when the
  divisor does not change inside the loop (section 6.7). C++ compilers keep
  the divide instruction there.
- **Reordered float sums are allowed per variable** with `~` and an error
  bound (section 6.3). In C++ the same freedom needs `-ffast-math` or
  similar, with no bound on the error.
- **Struct layout is chosen from the loops.** An array of structs can become
  one array per field (section 6.5), which in C++ means rewriting the code.
- **The GPU is in the same language.** A `gpu do` block in the same function
  as the CPU code around it, with the data movement worked out for you.

To race fairly, follow section 6.1: the same algorithm on both sides, C++ at
`-O3 -march=native`, identical answers, and the runs interleaved. When C++
wins a loop, compare what the two compile it to: `--jit-dump` writes
Century's machine code to a file for a disassembler, and `--ir` prints its
optimised intermediate code. A loop deep in a nest with many variables alive
at once, or a branch on random data, is the usual place to look.

### 6.10 A checklist

1. Measure with `clock()`, best of several warm runs.
2. Find the hot loop (`CY_PROFILE=1`).
3. Make it a counted loop over arrays in order, branch-free, in the narrowest
   correct type.
4. Give floating-point sums a `~` tolerance.
5. Mark independent loops `cpu do` (or `gpu do` for big, arithmetic-heavy,
   GPU-resident work) and confirm with `CY_PAR_COUNT=1` / `CY_GPU_STATS=1`.
6. Allocate once outside the loop; go through memory in order.
7. Measure again. Keep the change only if the answer is the same and the time
   went down.

---

## 7. What does not work yet

These are known limits. Most are things the compiler refuses with a message
rather than gets wrong.

| Limit | Do this instead |
|---|---|
| No `print`, and no keyboard input | Return a value, `writefile` bytes, or call the operating system through `extern`. |
| No `break`, `continue` or `else if` | Use a condition on the `while`, or nest `if` inside `else`. |
| No type annotations on bindings | `mut x = u32(0)`. |
| `for` walks arrays only | Count with `while`. Maps cannot be iterated. |
| Strings are constants | Work on `u8[]` bytes. `readfile` and `writefile` take a `u8[]` path. |
| `T[N]` fixed arrays cannot be created | Use `T[]` from `array[T](n)`. |
| In native code, arrays cannot hold strings, arrays, tuples, function values or sum types. The program is refused with a `cannot build IR: ...` message. | Use a struct with the parts as fields, a 2-D array (`array[T](r, c)`), or numeric codes instead of strings. |
| In native code, a struct nested inside an array element (`ps[i].pos.x`) cannot be reached, and a whole element cannot be read or assigned as one value (`ps[i] = P(...)`). | Keep array element structs flat and assign field by field: `ps[i].x = ...`. |
| In native code, map values must be numbers, `bool` or strings. | Keep a map from key to index, plus arrays of the fields. |
| `--jit` and built programs pass at most eight arguments, all integers or `bool` | Use `--ir-run` for more, and convert to floats inside. |
| `extern` functions cannot take structs or call back into Century, and do not run on `--ir-run` | Pass `u8[]` / `u32[]` buffers for C structs; run with `--jit` or build the program. |
| A built program's entry returns nothing, a number or a `bool` | Write anything bigger to a file with `writefile`. |
| Native array indexing is not bounds-checked | Debug with `--ir-run`, which checks every access. |
| In a `cpu do` block, a helper that writes an array at a subscript it computed from memory (`scratch[ids[k]] = ...`), or at a data-dependent offset inside the iteration's own slice, is refused even when the writes cannot collide. Reads at such subscripts are fine when the block does not write that array. | Write the scratch in the function that creates it, or index it by a loop counter. |
| `--ir-run` stops after 200 million steps (`ir: step limit`) | Use `--jit` for long runs. |

---

## 8. Every command-line flag

`century <file.cy> [flags...]`. The flags can come in any order after the file.

### Running

| Flag | Meaning |
|---|---|
| `--jit <fn>` | Compile the program to native x86-64 code and run `fn`. Prints `jit fn: N bytes (module M)` and then `jit fn = result`. Falls back to the interpreter if the CPU lacks what the code needs (section 3). |
| `--build [out.exe]` | Compile the program once into a standalone executable (section 2.5). Without a name, the source's name with `.exe`, in the current folder. Prints `built out.exe: N bytes of machine code, starting at main`. |
| `--entry <fn>` | With `--build`: the function the program starts at. Default `main`. |
| `--ir-run <fn>` | Run `fn` on the interpreter: slower, every access checked, stops at 200 million steps. |
| `--arg <N>` | One argument for `fn`, in decimal. Repeat for more. `--jit` uses up to eight. |
| `--opt <0-8>` | Optimisation level, default 8 (everything). Lower levels switch passes off. They exist to narrow down a suspected compiler bug: `--opt 0` runs the program as written. |
| `--no-opt` | The same as `--opt 0`. |
| `--no-parallel` | Run on one CPU thread with no GPU. Every result is the same as with threads. |
| `--no-gpu` | Keep CPU threads but never use the GPU. |
| `--gpu-approx` | Let the GPU compute `f32` division and square root at full hardware speed. Faster, but the last bit can differ from the CPU. |
| `--fma` | Fuse every `a * b + c` on floats into one fused multiply-add (one rounding instead of two). Faster, with slightly different last bits. Also turned on by the variable `CY_FMA`. |
| `--jit-time` | With `--jit`: run `fn` five more times with the first argument and print the best time in ms. The in-process timer is known to misreport some programs: prefer `clock()` inside the program, or timing a whole run. |

### GPU kernels

| Flag | Meaning |
|---|---|
| `--emit-spv <dir>` | Write the GPU kernel made from each `gpu` block as a SPIR-V file `k<i>_line<L>.spv` in `dir`, and say which blocks did not become kernels and why. |

### Looking inside

| Flag | Meaning |
|---|---|
| `--layout` | Print how each struct is laid out in memory, and whether arrays of structs were split into one array per field, with the reason. |
| `--tile-report` | Print what the loop passes did: fused loops, tiled nests, `cpu`/`gpu` blocks proved safe, arrays that need no zeroing. |
| `--check-overflow` | Try to prove that no integer operation can overflow. Lists every one it cannot prove, with the fix, and exits with code 1 if there are any. |
| `--time` | Print how long lexing and type checking took. |
| `--dump` | Print the checked program graph. |
| `--ir` | Print the optimised intermediate code. |
| `--codegen` | Compile to machine code without running, and print its size. |
| `--jit-dump <file>` | With `--jit`: write the raw machine code to a file, for a disassembler. |

Example of `--check-overflow`:

```
pub fn safe(n: u32 in 0..1000) -> u32
    return n * n + u32(1)
end

pub fn risky(a: u32, b: u32) -> u32
    return a * b
end
```

```
overflow.cy:7:0: error: risky:7: `*` on u32 is not proved - left is [0, 4294967295], right is [0, 4294967295], so the result is [0, 18446744065119617025] and u32 holds up to 4294967295
     7 | end
       | ^
       = help: nothing can see this function's callers, so the bound has to be written: `n: u32 in 0..N`
overflow obligations: 4 total, 3 proved, 1 UNPROVED
```

### Layout switches

| Flag | Meaning |
|---|---|
| `--no-soa` | Never split an array of structs into one array per field. |
| `--no-narrow` | Store every field at its declared width, even when a smaller one is proved enough. |
| `--no-pack` | Do not pack several small fields into one machine word. |
| `--no-tile` | Do not reshape loop nests for the cache. |

### Commands that replace the file argument

| Command | Meaning |
|---|---|
| `century --device` | The device scan (section 3). |
| `century --help` or `-h` | The usage summary. |
| `century --version` | The build date. |
| `century --test <dir>` | Type-check every `.cy` file in a directory. Each must pass, except files named `bad_*.cy`, which must be rejected. Prints one line per file and exits with 1 if any file did otherwise. |

### Specialist tools

| Flag or command | Meaning |
|---|---|
| `--ir-run <fn> --certify <body:in:out> [--prime P]` | Certifies that a loop body is a polynomial map over the integers mod P, and reports its degree. P defaults to 2013265921. |
| `--bench-build <fn> --bench-run <fn> [--label L]` | Benchmarking: build a structure once with one function, then time another over it nine times. |
| `century --seqcost`, `--seqagree`, `--seqmodel`, `--seqports`, `--superopt`, `--freemoves`, `--distbench` | Tools for compiler development that time instruction sequences on this CPU. They need the same CPU features as `--jit`. |

---

## 9. Environment variables

Set them in cmd with `set NAME=value`, or in PowerShell with `$env:NAME = "value"`.

| Variable | Meaning |
|---|---|
| `CY_THREADS=N` | Use at most N CPU threads. `CY_THREADS=1` is the quickest way to see what parallelism is worth. |
| `CY_PAR_COUNT=1` | After a run, count the entries into parallel regions: `par: 101 wide, 0 serial (work), 0 serial (tiny), largest turned down 0`. "serial (work)" ran on one thread for having too little work, and "largest turned down" is the biggest such work estimate. |
| `CY_PAR_WHY=1` | While compiling, print a line for each loop proved safe to run wide: `par: line 62 outlined, ...` when it became a parallel region, with the reason when it did not. |
| `CY_MIN_PAR_WORK=N` | The estimated work a parallel region needs before it is spread over the threads. The default, 2097152, is about half a millisecond. Lower it only when `CY_PAR_COUNT` shows a region turned down that measures faster wide. |
| `CY_PROFILE=1` | After a `--jit` run, print exact execution counts for the 24 hottest places in the program, by function and line. |
| `CY_GPU_STATS=1` | After a run, print where GPU time went: upload, dispatch, download, and one line per kernel. |
| `CY_GPU_SYNC=1` | With `CY_GPU_STATS`: wait after every GPU launch, so each kernel is timed on its own (slower overall). |
| `CY_GPU_WHY=1` | With `--jit`, print how many `gpu` blocks became GPU kernels, why a kernel fell back to the CPU while running, when a kernel moves to the faster side, and when a block's grid takes fewer of its nested loops than it has. (`--emit-spv` gives the reason for each block that never became a kernel.) |
| `CY_GPU_ROUTE=gpu` | Always run `gpu do` kernels on the GPU (`=cpu`: always on the CPU's threads). Without it each kernel goes to whichever side is faster for it (section 6.6). |
| `CY_SCOPE_REPORT=1` | While compiling, say which functions and loops give their memory back, and what keeps it when one does not. `CY_NO_LOOP_SCOPE=1` turns the per-pass release off. |
| `CY_CPU_OFF=avx2,sha` | Pretend the CPU lacks these features, to see the fallbacks of section 3 on any machine. Names: `sse42 popcnt avx avx2 fma bmi1 bmi2 lzcnt f16c sha avxvnni avx512`. |
| `CY_GPU_OFF=f64` | Pretend the GPU lacks these: `f64 i64 i16 i8`, or `all` for no GPU at all. |
| `CY_FMA=1` | The same as `--fma`. |

---

## 10. Errors and how to fix them

Every error shows the line, a caret under the spot, and usually the fix:

```
counter.cy:8:5: error: `hits` is not mutable
     8 |     c.hits = c.hits + u32(1)
       |     ^
       = help: declare the field as `mut hits: u32`
1 error, nothing emitted
```

The compiler reports every error it finds in one run, and nothing runs until
there are none. A refused `cpu do` or `gpu do` block is reported after the
`ok` line: the type check passed, and the independence proof comes after it.

| Message | Cause and fix |
|---|---|
| `arithmetic needs the same numeric type on both sides, found u32 and u64` | No implicit conversions. Convert one side: `u64(a) + b`. |
| `` `x` is immutable; declare it with `mut` to assign to it `` | Declare it with `mut x = ...`. |
| `` `x` is already declared in this scope `` | `mut x = ...` always declares. To change `x`, write `x = ...`. |
| `` an `if` condition must be bool, found u32 `` | Write the comparison: `if n != u32(0) then`. |
| `this expression has no effect; only a call may stand alone` | Bind the value: `mut old = atomic_add(...)`. |
| `` this `match` does not handle Empty `` | Add the missing `case`. There is no default case. |
| `a type name on its own is not a value` | A type name such as `i8` or `u32` was used as a variable. Rename the variable. |
| `` unknown name `xFF` `` | There are no hex literals. Write `255`. |
| `` expected `=` after a `mut` binding `` | Bindings take no type annotation: `mut x = u32(0)`. |
| `` this `cpu` block cannot be run wide: ... `` / `` this `gpu` block cannot be run wide: ... `` | The loop's iterations depend on each other. Each iteration must write only its own elements, or use `atomic_add`. The message says which access is the problem. |
| `` ... cannot be run wide: the body does something whose order cannot be reasoned about `` | The block calls an `extern` function, uses `push`, a map, a file or `clock()`. Move that out of the block. |
| `` ... cannot be run wide: it carries a value from one iteration to the next `` | A variable declared outside the block is assigned inside it. Declare it inside, or write one result per iteration into an array and total them afterwards. |
| `` cannot find `F` in `lib.dll` `` | An `extern` name is misspelt or the DLL is missing. Names are case-sensitive, and Windows text functions end in `A` or `W`. |
| `` `extern` parameter p has type T, which a C function cannot take `` | Use `bool`, an integer, `f32`, `f64`, `string` or an array of those (section 4.22). |
| `call through an unknown function value (an extern function in a DLL runs only on the native backend)` | `--ir-run` cannot call DLLs. Run with `--jit`. |
| `` no function named f: a program starts at `main`, or at the function --entry names `` | `--build` found no `main`. Write one, or name the entry with `--entry`. |
| `` cannot build out.exe: parameter `x` of `f` is f64: a program's entry takes whole numbers or bools ... `` | The entry's parameters come from the command line: take an integer and convert it inside. |
| `` cannot build out.exe: `f` returns u32[], and a program's entry returns nothing, a number or a bool `` | Return a number, or write the array to a file. |
| `cannot build out.exe: cannot replace the output file (is that program still running?)` | Close the running copy, then build again. |
| `` prog.exe: `x` is not a u32 for n (...) `` and `usage: prog.exe <n: u32>` | A built program was given a wrong or missing argument. The usage line lists what it takes. |
| `prog.exe: this program file is damaged - build it again` | The file was changed or cut short after it was built. |
| `the program stopped on an access violation ...` (from a built program) | Most often an index past the end of an array. Run the source with `century prog.cy --ir-run main --arg ...` to find which. |
| `cannot build IR: no place for a field` | An array of strings, arrays, tuples or function values (section 7). |
| `cannot build IR: ...` (any other) | Something the native backend does not handle yet, such as a whole array element used as a value. The message names it; section 7 lists the workarounds. |
| `century: this CPU has no ..., so f runs on the interpreter` | Not an error: the program runs and gives the same answer, more slowly (section 3). |
| `century: the program stopped on an access violation ...` | Most often an index past the end of an array. Rerun with `--ir-run` to see which. |
| `century: the compiler itself stopped ...` | A bug in Century. The source file that triggers it is what is needed to fix it. |
| `ir: step limit` | `--ir-run` stops after 200 million steps. Use `--jit`. |

---

## 11. A complete example

```
-- shapes.cy: structs, a sum type, an array of structs, a parallel loop,
-- the clock, an operating-system call, and a file written out

extern "kernel32.dll" fn GetCurrentProcessId() -> u32

type Vec2
    x: f64
    y: f64
end

type Shape
    case Circle(centre: Vec2, r: f64)
    case Rect(corner: Vec2, w: f64, h: f64)
    case Empty
end

type Particle
    mut x: f64
    mut y: f64
    mut vx: f64
    mut vy: f64
end

fn area(s: Shape) -> f64
    match s
        case Circle(c, r) then
            return 3.14159265358979 * r * r
        case Rect(c, w, h) then
            return w * h
        case Empty then
            return 0.0
    end
end

-- total area of n shapes, alternating circles and rectangles
pub fn areas(n: u32) -> f64
    mut total = 0.0
    mut i = u32(0)
    while i < n do
        o = Vec2(x: 0.0, y: 0.0)
        mut s = Shape.Empty
        if i % u32(2) == u32(0) then
            s = Shape.Circle(o, 1.0)
        else
            s = Shape.Rect(o, 2.0, f64(i))
        end
        total = total + area(s)
        i = i + u32(1)
    end
    return total
end

-- move n particles for `steps` steps on every CPU thread; how many end right of x = 10?
pub fn simulate(n: u32, steps: u32) -> u32
    mut ps = array[Particle](n)
    mut i = u32(0)
    while i < n do
        ps[i].vx = f64(i % u32(7)) * 0.5
        ps[i].vy = 1.0
        i = i + u32(1)
    end
    mut t = u32(0)
    while t < steps do
        cpu do
            mut k = u32(0)
            while k < n do
                ps[k].x = ps[k].x + ps[k].vx
                ps[k].y = ps[k].y + ps[k].vy
                k = k + u32(1)
            end
        end
        t = t + u32(1)
    end
    mut right = u32(0)
    for p in ps do
        right = right + u32(p.x > 10.0)
    end
    return right
end

-- how long simulate(n, 100) takes, in milliseconds
pub fn timesim(n: u32) -> f64
    t0 = clock()
    r = simulate(n, u32(100))
    return (clock() - t0) * 1000.0
end

-- writes "count: <n>" and a newline to report.txt; returns the bytes written
pub fn report(n: u32) -> u32
    mut out = array[u8](0)
    for b in bytes("count: ") do
        push(out, b)
    end
    mut digits = array[u8](0)
    mut v = n
    if v == u32(0) then
        push(digits, u8(48))
    end
    while v > u32(0) do
        push(digits, u8(v % u32(10)) + u8(48))
        v = v / u32(10)
    end
    mut k = len(digits)
    while k > u32(0) do
        k = k - u32(1)
        push(out, digits[k])
    end
    push(out, u8(10))
    return writefile("report.txt", out)
end

-- this process's id, from Windows
pub fn whoami() -> u32
    return GetCurrentProcessId()
end
```

```
century shapes.cy --jit areas --arg 10
jit areas = 4634324203794507530
jit areas as f64 = 65.707963267948941

century shapes.cy --jit simulate --arg 100 --arg 30
jit simulate = 85

century shapes.cy --jit report --arg 1234
jit report = 12
```

and `report.txt` holds `count: 1234`. `timesim` returns milliseconds as an
`f64` (on the `as f64` line), and `whoami` the process id. Each command also
prints its `ok` line and the machine code size first; they are left out here.
