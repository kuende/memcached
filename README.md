# Memcached

[![Build Status](https://travis-ci.org/kuende/memcached.svg)](https://travis-ci.org/kuende/memcached)

Crystal client for Memcached using the text procotol.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  memcached:
    github: kuende/memcached
```


## Usage


```crystal
require "memcached"

client = Memcached::Client.new("localhost", "11211")

client.set("foo", "bar") # sets key foo=bar
client.set("foo", "bar", ttl: 3) # set key foo=bar, expire after 3 seconds

client.get("foo") # gets key foo
client.get_multi(["foo", "other"]) => {"foo" => "bar", "other" => nil}

client.add("foo", "bar") # set foo=bar only if foo=nil
client.replace("foo", "bar") # set foo=bar only if foo!=nil

client.incr("counter") # increments counter by 1
client.incr("counter", 2) # increments counter by 2
client.decr("counter") # decrements counter by 1
client.decr("counter", 2) # decrements counter by 2

client.append("key", "foo") # appends value foo to key
client.prepend("key", "foo") # prepends value foo to key

client.delete("foo") # deletes key "foo"
client.flush # deletes all keys

```

### Implemented

- [x] get
- [x] get_multi
- [x] set
- [x] add
- [x] replace
- [x] delete
- [x] flush
- [x] append
- [x] prepend
- [x] increment
- [x] decrement
- [ ] touch

## Contributing

1. Fork it ( https://github.com/kuende/memcached/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request
