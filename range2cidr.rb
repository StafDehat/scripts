#!/usr/bin/ruby

# Author: Unknown
#
require 'ipaddr'
require 'socket'

def range_cidr(first, last, &block)
  if first < last
    idx1 = 32
    idx1 -= 1 while first[idx1] == last[idx1]
    prefix = first >> idx1+1 << idx1+1

    idx2 = 0
    idx2 += 1 while idx2 <= idx1 and first[idx2] == 0 and last[idx2] == 1

    if idx2 <= idx1
      range_cidr(first, prefix | 2**idx1-1, &block)
      range_cidr(prefix | 1 << idx1, last, &block)
    else
      yield prefix, 32-idx2
    end
  else
    yield first, 32
  end
end


if __FILE__ == $0
  if ARGV.size == 2
    range_cidr(IPAddr.new(ARGV[0]).to_i, IPAddr.new(ARGV[1]).to_i) { |subnet, mask|
      puts "#{IPAddr.new(subnet, Socket::AF_INET).to_s}/#{mask}"  }
  else
    puts "usage: range2cidr <first_ip> <last_ip>"
    puts "example: range2cidr 192.168.1.0 192.168.2.255"
  end
end
