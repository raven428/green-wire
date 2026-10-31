use std::fmt;
use std::net::Ipv4Addr;
// ipv4 network with cleared host bits
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Net {
  addr: u32,
  prefix: u8,
}
impl Net {
  pub fn new(addr: u32, prefix: u8) -> Self {
    Self {
      addr: addr & mask(prefix),
      prefix,
    }
  }
  pub fn host(addr: Ipv4Addr) -> Self {
    Self::new(addr.into(), 32)
  }
  // address, address/prefix or address/netmask
  pub fn parse(s: &str) -> Result<Self, String> {
    let (addr, len) = s.split_once('/').unwrap_or((s, "32"));
    if len.contains('.') {
      return Self::with_mask(addr, len);
    }
    let addr = parse_addr(addr)?;
    match len.parse::<u8>() {
      Ok(prefix) if prefix <= 32 => Ok(Self::new(addr, prefix)),
      _ => Err(format!("bad prefix [{len}]")),
    }
  }
  pub fn with_mask(addr: &str, netmask: &str) -> Result<Self, String> {
    let prefix = prefix_of(parse_addr(netmask)?)
      .ok_or_else(|| format!("bad netmask [{netmask}]"))?;
    Ok(Self::new(parse_addr(addr)?, prefix))
  }
  pub const fn prefix(self) -> u8 {
    self.prefix
  }
  pub const fn first(self) -> u32 {
    self.addr
  }
  pub fn last(self) -> u32 {
    self.addr | !mask(self.prefix)
  }
  pub fn contains(self, other: Self) -> bool {
    self.prefix <= other.prefix && other.addr & mask(self.prefix) == self.addr
  }
}
impl fmt::Display for Net {
  fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
    let addr = Ipv4Addr::from(self.addr);
    if self.prefix == 32 {
      write!(f, "{addr}")
    } else {
      write!(f, "{addr}/{}", self.prefix)
    }
  }
}
// std parser accepts canonical octets only, as dnsmasq and nft do
fn parse_addr(s: &str) -> Result<u32, String> {
  s.parse::<Ipv4Addr>()
    .map(u32::from)
    .map_err(|_| format!("bad address [{s}]"))
}
fn mask(prefix: u8) -> u32 {
  u32::MAX.checked_shl(32 - u32::from(prefix)).unwrap_or(0)
}
// prefix length of contiguous netmask
pub fn prefix_of(netmask: u32) -> Option<u8> {
  let ones = netmask.leading_ones();
  if ones + netmask.trailing_zeros() != 32 {
    return None;
  }
  u8::try_from(ones).ok()
}
// sorted disjoint ranges of addresses, overlapping and adjacent ones are merged
#[derive(Clone, Debug, Default)]
pub struct NetSet {
  ranges: Vec<(u32, u32)>,
}
impl NetSet {
  pub fn add(&mut self, net: Net) {
    let (mut lo, mut hi) = (net.first(), net.last());
    let mut kept = Vec::with_capacity(self.ranges.len() + 1);
    for &(a, b) in &self.ranges {
      if u64::from(b) + 1 < u64::from(lo) || u64::from(hi) + 1 < u64::from(a) {
        kept.push((a, b));
      } else {
        lo = lo.min(a);
        hi = hi.max(b);
      }
    }
    kept.push((lo, hi));
    kept.sort_unstable();
    self.ranges = kept;
  }
  // true if something was cut out
  pub fn remove(&mut self, net: Net) -> bool {
    let (lo, hi) = (net.first(), net.last());
    let mut cut = false;
    let mut kept = Vec::with_capacity(self.ranges.len() + 1);
    for &(a, b) in &self.ranges {
      if b < lo || a > hi {
        kept.push((a, b));
        continue;
      }
      cut = true;
      if a < lo {
        kept.push((a, lo - 1));
      }
      if b > hi {
        kept.push((hi + 1, b));
      }
    }
    self.ranges = kept;
    cut
  }
  // minimal list of networks covering the set
  pub fn nets(&self) -> Vec<Net> {
    let mut nets = Vec::new();
    for &(a, b) in &self.ranges {
      let (mut start, end) = (u64::from(a), u64::from(b) + 1);
      while start < end {
        // the widest aligned block starting at start and fitting into the range
        let bits = start.trailing_zeros().min(32).min((end - start).ilog2());
        let addr = u32::try_from(start).unwrap_or(u32::MAX);
        nets.push(Net::new(addr, u8::try_from(32 - bits).unwrap_or(32)));
        start += 1 << bits;
      }
    }
    nets
  }
}
#[cfg(test)]
mod tests {
  use super::*;
  fn set(list: &[&str]) -> NetSet {
    let mut set = NetSet::default();
    for n in list {
      set.add(Net::parse(n).unwrap());
    }
    set
  }
  fn show(set: &NetSet) -> Vec<String> {
    set.nets().iter().map(ToString::to_string).collect()
  }
  #[test]
  fn parse() {
    assert_eq!(Net::parse("10.1.2.3").unwrap().to_string(), "10.1.2.3");
    assert_eq!(
      Net::parse("10.1.2.3/24").unwrap().to_string(),
      "10.1.2.0/24"
    );
    assert_eq!(
      Net::parse("10.1.2.3/255.255.0.0").unwrap().to_string(),
      "10.1.0.0/16"
    );
    assert_eq!(Net::parse("0.0.0.0/0").unwrap().to_string(), "0.0.0.0/0");
    assert!(Net::parse("10.01.2.3").is_err());
    assert!(Net::parse("10.1.2.256").is_err());
    assert!(Net::parse("10.1.2.3/33").is_err());
    assert!(Net::parse("10.1.2.3/255.0.255.0").is_err());
    assert!(Net::parse("").is_err());
  }
  #[test]
  fn contains() {
    let big = Net::parse("10.0.0.0/8").unwrap();
    let small = Net::parse("10.20.30.0/24").unwrap();
    assert!(big.contains(small));
    assert!(!small.contains(big));
    assert!(Net::parse("0.0.0.0/0").unwrap().contains(small));
  }
  #[test]
  fn merge() {
    assert_eq!(
      show(&set(&["10.0.0.0/25", "10.0.0.128/25"])),
      ["10.0.0.0/24"]
    );
    assert_eq!(show(&set(&["10.0.0.0/8", "10.1.0.0/16"])), ["10.0.0.0/8"]);
    assert_eq!(show(&set(&["10.0.0.5", "10.0.0.4"])), ["10.0.0.4/31"]);
    assert_eq!(
      show(&set(&["10.0.0.1", "10.0.0.2"])),
      ["10.0.0.1", "10.0.0.2"]
    );
    assert_eq!(show(&set(&["0.0.0.0/0", "1.2.3.4"])), ["0.0.0.0/0"]);
    assert_eq!(
      show(&set(&["255.255.255.255", "0.0.0.0"])),
      ["0.0.0.0", "255.255.255.255"]
    );
  }
  #[test]
  fn remove() {
    let mut s = set(&["192.168.0.0/16"]);
    assert!(s.remove(Net::parse("192.168.69.0/24").unwrap()));
    assert_eq!(
      show(&s),
      [
        "192.168.0.0/18",
        "192.168.64.0/22",
        "192.168.68.0/24",
        "192.168.70.0/23",
        "192.168.72.0/21",
        "192.168.80.0/20",
        "192.168.96.0/19",
        "192.168.128.0/17"
      ]
    );
    assert!(!s.remove(Net::parse("10.0.0.0/8").unwrap()));
    let mut s = set(&["10.0.0.0/30"]);
    assert!(s.remove(Net::parse("10.0.0.0/24").unwrap()));
    assert_eq!(show(&s), Vec::<String>::new());
  }
}
