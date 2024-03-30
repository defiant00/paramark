# (mark) | [Specification](SPECIFICATION.md)

![CLI Version](https://img.shields.io/badge/(mark)%20CLI-0.1.0-brightgreen)
![Spec Version](https://img.shields.io/badge/Spec-0.1.0-blue)

Implemented in [Zig](https://ziglang.org/), last compiled with 0.12.0-dev.3033+031f23117.

```
(-pm v="1.0"-)
(-comment-)(---comment, the number of dashes must match---)
(tag(content, ((parens)) are doubled)tag)
(self-closing)
(tag flag-1 flag.2 prop_1=val prop2="some value" "quoted flag" "quoted key"=val)
( "quoted tag"(need a space between (( and a quoted tag to differentiate from literal text)"quoted tag")
("literal text, such as (parens)")
("""
"literal text, the number of opening and closing quotes must match" - (mark) spec
""")
(first(tags (second(can be)first) interleaved)second)
(tag 1(closing tags are (tag 2(matched on both name)tag 1) and optionally any properties)tag 2)
```
