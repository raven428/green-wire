use crate::config::Config;
use crate::net::{Net, NetSet};
use std::collections::HashMap;
use std::fmt::Write as _;
use std::net::Ipv4Addr;
use toml::Value;
// pushed networks entirely within one of these ranges are ignored
const GRAY: &[([u8; 4], u8)] = &[
  ([0, 0, 0, 0], 8),
  ([10, 0, 0, 0], 8),
  ([100, 64, 0, 0], 10),
  ([127, 0, 0, 0], 8),
  ([169, 254, 0, 0], 16),
  ([172, 16, 0, 0], 12),
  ([192, 168, 0, 0], 16),
  ([224, 0, 0, 0], 3),
];
// destinations for the tunnel and dns servers for domains, with verdicts for the log
pub struct Plan {
  pub dst: NetSet,
  pub dns: Vec<Ipv4Addr>,
  pub domains: Vec<String>,
  pub log: Vec<String>,
}
impl Plan {
  pub fn new(env: &HashMap<String, String>, config: &Config) -> Self {
    let mut log = Vec::new();
    let public = public_setting(config.public.as_ref(), &mut log);
    // pushed public routes via net_gateway are exceptions from the tunnel
    let net_gw = env.get("route_net_gateway").filter(|gw| !gw.is_empty());
    let mut bypass = NetSet::default();
    let mut dst = NetSet::default();
    for i in 1.. {
      let Some(network) = env.get(&format!("route_network_{i}")) else {
        break;
      };
      let netmask = env
        .get(&format!("route_netmask_{i}"))
        .map_or("255.255.255.255", String::as_str);
      let gw = env
        .get(&format!("route_gateway_{i}"))
        .filter(|gw| !gw.is_empty());
      let via = gw.map_or("unknown", String::as_str);
      let net = match Net::with_mask(network, netmask) {
        Ok(net) => net,
        Err(e) => {
          log.push(format!(
            "push route {network}/{netmask} via {via}: {e}, ignored"
          ));
          continue;
        }
      };
      if within(net, GRAY) {
        log.push(format!("push route {net} via {via}: private, ignored"));
      } else if net_gw.is_some() && gw == net_gw {
        log.push(format!("push route {net} via net_gateway: bypass"));
        bypass.add(net);
      } else {
        match public {
          None => log.push(format!("push route {net} via {via}: public, ignored")),
          Some(max) if net.prefix() < max => log.push(format!(
            "push route {net} via {via}: public wider than /{max}, ignored"
          )),
          Some(_) => {
            log.push(format!("push route {net} via {via}: public, accepted"));
            dst.add(net);
          }
        }
      }
    }
    let mut dns = Vec::new();
    let mut domains = Vec::new();
    for i in 1.. {
      let Some(option) = env.get(&format!("foreign_option_{i}")) else {
        break;
      };
      let mut words = option.split_whitespace();
      match (words.next(), words.next(), words.next()) {
        (Some("dhcp-option"), Some("DNS"), Some(value)) => {
          match value.parse::<Ipv4Addr>() {
            Ok(addr) => {
              log.push(format!("push dns {addr}: accepted"));
              push_new(&mut dns, addr);
            }
            Err(_) => {
              log.push(format!("push dns {value}: bad address [{value}], ignored"));
            }
          }
        }
        (Some("dhcp-option"), Some("DOMAIN"), Some(value)) => {
          log.push(format!("push domain {value}"));
          push_new(&mut domains, value.to_owned());
        }
        _ => log.push(format!("push option: {option}")),
      }
    }
    for &addr in &dns {
      dst.add(Net::host(addr));
    }
    add_own_nets(&config.nets, &mut dst, &mut log);
    add_own_domains(config.domains.as_ref(), &mut domains, &mut log);
    for net in bypass.nets() {
      if dst.remove(net) {
        log.push(format!("cut [{net}] routed via net_gateway"));
      }
    }
    Self {
      dst,
      dns,
      domains,
      log,
    }
  }
  pub fn dnsmasq_conf(&self) -> String {
    let mut conf = String::new();
    for domain in &self.domains {
      for dns in &self.dns {
        let _ = writeln!(conf, "server=/{domain}/{dns}");
      }
    }
    conf
  }
}
// missing value ignores pushed public networks, a non-string one is bad
fn public_setting(value: Option<&Value>, log: &mut Vec<String>) -> Option<u8> {
  match value? {
    Value::String(value) => public_max(value, log),
    value => {
      log.push(format!("bad public [{value}], using \"none\""));
      None
    }
  }
}
// "none" ignores pushed public networks, "/N" accepts them up to /N
fn public_max(value: &str, log: &mut Vec<String>) -> Option<u8> {
  if value == "none" {
    return None;
  }
  let max = value
    .strip_prefix('/')
    .filter(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))
    .and_then(|n| n.parse::<u8>().ok())
    .filter(|&n| n <= 32);
  if max.is_none() {
    log.push(format!("bad public [{value}], using \"none\""));
  }
  max
}
// bad elements are skipped, so the rest of the list still works
fn add_own_nets(items: &[Value], dst: &mut NetSet, log: &mut Vec<String>) {
  for item in items {
    let Some(text) = item.as_str() else {
      log.push(format!("own net {item}: not a string, ignored"));
      continue;
    };
    match Net::parse(text) {
      Ok(net) => {
        log.push(format!("own net {net}"));
        dst.add(net);
      }
      Err(e) => log.push(format!("own net {text}: {e}, ignored")),
    }
  }
}
// a bad value or element is skipped, so the hook still works with the rest
fn add_own_domains(value: Option<&Value>, dst: &mut Vec<String>, log: &mut Vec<String>) {
  let Some(value) = value else { return };
  let Some(items) = value.as_array() else {
    log.push(format!("bad domains [{value}], ignored"));
    return;
  };
  for item in items {
    let Some(domain) = item.as_str() else {
      log.push(format!("own domain {item}: not a string, ignored"));
      continue;
    };
    log.push(format!("own domain {domain}"));
    push_new(dst, domain.to_owned());
  }
}
fn within(net: Net, list: &[([u8; 4], u8)]) -> bool {
  list
    .iter()
    .any(|&(addr, prefix)| Net::new(u32::from_be_bytes(addr), prefix).contains(net))
}
fn push_new<T: PartialEq>(list: &mut Vec<T>, item: T) {
  if !list.contains(&item) {
    list.push(item);
  }
}
#[cfg(test)]
mod tests {
  use super::*;
  const EMPTY: [&str; 0] = [];
  const VPN_GW: &str = "10.8.0.1";
  const NET_GW: &str = "192.168.69.1";
  // routes as (network, netmask, gateway), net_gateway is NET_GW
  fn env(routes: &[(&str, &str, &str)], options: &[&str]) -> HashMap<String, String> {
    let mut vars = HashMap::new();
    vars.insert("route_net_gateway".to_owned(), NET_GW.to_owned());
    for (i, &(net, mask, gw)) in routes.iter().enumerate() {
      let i = i + 1;
      vars.insert(format!("route_network_{i}"), net.to_owned());
      vars.insert(format!("route_netmask_{i}"), mask.to_owned());
      vars.insert(format!("route_gateway_{i}"), gw.to_owned());
    }
    for (i, &option) in options.iter().enumerate() {
      vars.insert(format!("foreign_option_{}", i + 1), option.to_owned());
    }
    vars
  }
  fn config(nets: &[&str], public: Option<&str>, domains: &[&str]) -> Config {
    Config {
      nets: nets.iter().map(|&n| Value::from(n)).collect(),
      public: public.map(Value::from),
      domains: Some(Value::from(domains.to_vec())),
    }
  }
  fn show(plan: &Plan) -> Vec<String> {
    plan.dst.nets().iter().map(ToString::to_string).collect()
  }
  #[test]
  fn example() {
    let vars = env(
      &[
        ("10.0.0.0", "255.0.0.0", VPN_GW),
        ("203.0.113.4", "255.255.255.252", VPN_GW),
        ("203.0.113.8", "255.255.255.248", VPN_GW),
        ("198.51.100.7", "255.255.255.255", NET_GW),
        ("10.20.30.0", "255.255.255.0", NET_GW),
        ("10.1.1.1", "255.0.255.0", VPN_GW),
      ],
      &[
        "dhcp-option DNS 10.10.0.53",
        "dhcp-option DNS fe80::1",
        "dhcp-option DOMAIN corp.example",
        "redirect-gateway def1",
        "dhcp-option DNS 10.10.0.53",
      ],
    );
    let conf = config(
      &[
        "10.20.30.40",
        "10.20.31.0/24",
        "10.20.32.0/255.255.255.0",
        "198.51.100.0/24",
        "bad",
      ],
      Some("/30"),
      &["corp.example", "other.example"],
    );
    let plan = Plan::new(&vars, &conf);
    assert_eq!(
      plan.log,
      [
        "push route 10.0.0.0/8 via 10.8.0.1: private, ignored",
        "push route 203.0.113.4/30 via 10.8.0.1: public, accepted",
        "push route 203.0.113.8/29 via 10.8.0.1: public wider than /30, ignored",
        "push route 198.51.100.7 via net_gateway: bypass",
        "push route 10.20.30.0/24 via 192.168.69.1: private, ignored",
        "push route 10.1.1.1/255.0.255.0 via 10.8.0.1: \
          bad netmask [255.0.255.0], ignored",
        "push dns 10.10.0.53: accepted",
        "push dns fe80::1: bad address [fe80::1], ignored",
        "push domain corp.example",
        "push option: redirect-gateway def1",
        "push dns 10.10.0.53: accepted",
        "own net 10.20.30.40",
        "own net 10.20.31.0/24",
        "own net 10.20.32.0/24",
        "own net 198.51.100.0/24",
        "own net bad: bad address [bad], ignored",
        "own domain corp.example",
        "own domain other.example",
        "cut [198.51.100.7] routed via net_gateway",
      ]
    );
    assert_eq!(
      show(&plan),
      [
        "10.10.0.53",
        "10.20.30.40",
        "10.20.31.0/24",
        "10.20.32.0/24",
        "198.51.100.0/30",
        "198.51.100.4/31",
        "198.51.100.6",
        "198.51.100.8/29",
        "198.51.100.16/28",
        "198.51.100.32/27",
        "198.51.100.64/26",
        "198.51.100.128/25",
        "203.0.113.4/30"
      ]
    );
    assert_eq!(
      plan.dnsmasq_conf(),
      "server=/corp.example/10.10.0.53\n\
        server=/other.example/10.10.0.53\n"
    );
  }
  #[test]
  fn public_none() {
    let vars = env(
      &[
        ("203.0.113.4", "255.255.255.252", VPN_GW),
        ("198.51.100.7", "255.255.255.255", NET_GW),
      ],
      &["dhcp-option DNS 198.51.100.7"],
    );
    for public in [None, Some("none")] {
      let plan = Plan::new(&vars, &config(&["198.51.100.6/31"], public, &[]));
      assert_eq!(
        plan.log,
        [
          "push route 203.0.113.4/30 via 10.8.0.1: public, ignored",
          "push route 198.51.100.7 via net_gateway: bypass",
          "push dns 198.51.100.7: accepted",
          "own net 198.51.100.6/31",
          "cut [198.51.100.7] routed via net_gateway",
        ]
      );
      assert_eq!(show(&plan), ["198.51.100.6"]);
      assert_eq!(plan.dns, [Ipv4Addr::new(198, 51, 100, 7)]);
    }
  }
  #[test]
  fn public_values() {
    let mut log = Vec::new();
    for (value, max) in [
      ("none", None),
      ("/0", Some(0)),
      ("/30", Some(30)),
      ("/32", Some(32)),
    ] {
      assert_eq!(public_max(value, &mut log), max, "{value}");
    }
    assert_eq!(log, EMPTY);
    for value in ["30", "/33", "all", "/", "/+3", "", "None", "/3 0", " /30"] {
      let mut log = Vec::new();
      assert_eq!(public_max(value, &mut log), None, "{value}");
      assert_eq!(log, [format!("bad public [{value}], using \"none\"")]);
    }
    let vars = env(&[("203.0.113.4", "255.255.255.252", VPN_GW)], &[]);
    let plan = Plan::new(&vars, &config(&[], Some("30"), &[]));
    assert_eq!(
      plan.log,
      [
        "bad public [30], using \"none\"",
        "push route 203.0.113.4/30 via 10.8.0.1: public, ignored",
      ]
    );
    assert_eq!(show(&plan), EMPTY);
  }
  #[test]
  fn wrong_types() {
    let conf = crate::config::parse(
      "nets = [\"10.20.31.0/24\", 42, [\"10.20.32.0/24\"]]\npublic = 30",
    )
    .unwrap();
    let vars = env(&[("203.0.113.4", "255.255.255.252", VPN_GW)], &[]);
    let plan = Plan::new(&vars, &conf);
    assert_eq!(
      plan.log,
      [
        "bad public [30], using \"none\"",
        "push route 203.0.113.4/30 via 10.8.0.1: public, ignored",
        "own net 10.20.31.0/24",
        "own net 42: not a string, ignored",
        "own net [\"10.20.32.0/24\"]: not a string, ignored",
      ]
    );
    assert_eq!(show(&plan), ["10.20.31.0/24"]);
  }
  #[test]
  fn wrong_domains() {
    let vars = env(&[], &["dhcp-option DNS 10.10.0.53"]);
    let text = "domains = [\"a.example\", 1, [\"b.example\"], \"c.example\"]";
    let plan = Plan::new(&vars, &crate::config::parse(text).unwrap());
    assert_eq!(
      plan.log,
      [
        "push dns 10.10.0.53: accepted",
        "own domain a.example",
        "own domain 1: not a string, ignored",
        "own domain [\"b.example\"]: not a string, ignored",
        "own domain c.example",
      ]
    );
    assert_eq!(plan.domains, ["a.example", "c.example"]);
    for text in ["domains = \"a.example\"", "domains = 1", "domains = {}"] {
      let plan = Plan::new(&vars, &crate::config::parse(text).unwrap());
      let value = text.trim_start_matches("domains = ");
      assert_eq!(
        plan.log,
        [
          "push dns 10.10.0.53: accepted".to_owned(),
          format!("bad domains [{value}], ignored")
        ]
      );
      assert_eq!(plan.domains, EMPTY);
    }
    let plan = Plan::new(&vars, &crate::config::parse("domains = []").unwrap());
    assert_eq!(plan.log, ["push dns 10.10.0.53: accepted"]);
    assert_eq!(plan.domains, EMPTY);
  }
  #[test]
  fn bypass_cuts_push() {
    let vars = env(
      &[
        ("203.0.113.4", "255.255.255.252", VPN_GW),
        ("203.0.113.5", "255.255.255.255", NET_GW),
        ("203.0.113.9", "255.255.255.255", VPN_GW),
        ("203.0.113.9", "255.255.255.255", NET_GW),
      ],
      &[],
    );
    let plan = Plan::new(&vars, &config(&[], Some("/30"), &[]));
    assert_eq!(
      plan.log,
      [
        "push route 203.0.113.4/30 via 10.8.0.1: public, accepted",
        "push route 203.0.113.5 via net_gateway: bypass",
        "push route 203.0.113.9 via 10.8.0.1: public, accepted",
        "push route 203.0.113.9 via net_gateway: bypass",
        "cut [203.0.113.5] routed via net_gateway",
        "cut [203.0.113.9] routed via net_gateway",
      ]
    );
    assert_eq!(show(&plan), ["203.0.113.4", "203.0.113.6/31"]);
  }
  #[test]
  fn halves() {
    let vars = env(
      &[
        ("0.0.0.0", "128.0.0.0", VPN_GW),
        ("128.0.0.0", "128.0.0.0", VPN_GW),
      ],
      &[],
    );
    for public in ["/0", "/1"] {
      let plan = Plan::new(&vars, &config(&[], Some(public), &[]));
      assert_eq!(show(&plan), ["0.0.0.0/0"], "{public}");
    }
    let plan = Plan::new(&vars, &config(&[], Some("/2"), &[]));
    assert_eq!(show(&plan), EMPTY);
  }
  #[test]
  fn gray() {
    let gray = [
      ("0.0.0.0", "255.0.0.0"),
      ("10.0.0.0", "255.0.0.0"),
      ("10.1.2.3", "255.255.255.255"),
      ("100.64.0.0", "255.192.0.0"),
      ("127.0.0.1", "255.255.255.255"),
      ("169.254.1.0", "255.255.255.0"),
      ("172.16.0.0", "255.240.0.0"),
      ("172.31.255.0", "255.255.255.0"),
      ("192.168.0.0", "255.255.0.0"),
      ("224.0.0.0", "224.0.0.0"),
      ("255.255.255.255", "255.255.255.255"),
    ];
    for (net, mask) in gray {
      for gw in [VPN_GW, NET_GW] {
        let vars = env(&[(net, mask, gw)], &[]);
        let plan = Plan::new(&vars, &config(&[], Some("/0"), &[]));
        assert_eq!(show(&plan), EMPTY, "{net}/{mask} via {gw}");
        assert_eq!(plan.log.len(), 1);
        assert!(
          plan.log[0].ends_with(": private, ignored"),
          "{}",
          plan.log[0]
        );
      }
    }
    let white = [
      ("0.0.0.0", "254.0.0.0"),
      ("11.0.0.0", "255.0.0.0"),
      ("100.128.0.0", "255.192.0.0"),
      ("172.0.0.0", "255.0.0.0"),
      ("172.32.0.0", "255.255.0.0"),
      ("192.169.0.0", "255.255.0.0"),
      ("223.255.255.255", "255.255.255.255"),
    ];
    for (net, mask) in white {
      let vars = env(&[(net, mask, VPN_GW)], &[]);
      let plan = Plan::new(&vars, &config(&[], Some("/0"), &[]));
      assert_eq!(show(&plan).len(), 1, "{net}/{mask}");
      assert!(
        plan.log[0].ends_with(": public, accepted"),
        "{}",
        plan.log[0]
      );
    }
    // gray push via net_gateway is not an exception
    let vars = env(&[("192.168.1.0", "255.255.255.0", NET_GW)], &[]);
    let plan = Plan::new(&vars, &config(&["192.168.1.0/24"], None, &[]));
    assert_eq!(show(&plan), ["192.168.1.0/24"]);
    assert_eq!(
      plan.log,
      [
        "push route 192.168.1.0/24 via 192.168.69.1: private, ignored",
        "own net 192.168.1.0/24",
      ]
    );
  }
  #[test]
  fn route_defaults() {
    let mut vars = HashMap::new();
    for (key, value) in [
      ("route_net_gateway", ""),
      ("route_network_1", "203.0.113.7"),
      ("route_network_2", "203.0.113.9"),
      ("route_gateway_2", ""),
      ("route_network_4", "203.0.113.11"),
    ] {
      vars.insert(key.to_owned(), value.to_owned());
    }
    let plan = Plan::new(&vars, &config(&[], Some("/32"), &[]));
    assert_eq!(
      plan.log,
      [
        "push route 203.0.113.7 via unknown: public, accepted",
        "push route 203.0.113.9 via unknown: public, accepted",
      ]
    );
    assert_eq!(show(&plan), ["203.0.113.7", "203.0.113.9"]);
  }
  #[test]
  fn options() {
    let vars = env(
      &[],
      &[
        "dhcp-option DNS",
        "dhcp-option DNS6 2001:db8::1",
        "dhcp-option DOMAIN corp.example",
        "block-outside-dns",
        "dhcp-option DOMAIN corp.example",
      ],
    );
    let plan = Plan::new(&vars, &config(&[], None, &["own.example", "corp.example"]));
    assert_eq!(
      plan.log,
      [
        "push option: dhcp-option DNS",
        "push option: dhcp-option DNS6 2001:db8::1",
        "push domain corp.example",
        "push option: block-outside-dns",
        "push domain corp.example",
        "own domain own.example",
        "own domain corp.example",
      ]
    );
    assert_eq!(plan.domains, ["corp.example", "own.example"]);
    assert_eq!(show(&plan), EMPTY);
    assert_eq!(plan.dnsmasq_conf(), "");
  }
  #[test]
  fn dnsmasq() {
    let vars = env(
      &[],
      &[
        "dhcp-option DNS 10.10.0.53",
        "dhcp-option DOMAIN corp.example",
        "dhcp-option DNS 10.20.30.5",
      ],
    );
    let plan = Plan::new(&vars, &config(&[], None, &["other.example"]));
    assert_eq!(
      plan.dnsmasq_conf(),
      "server=/corp.example/10.10.0.53\n\
        server=/corp.example/10.20.30.5\n\
        server=/other.example/10.10.0.53\n\
        server=/other.example/10.20.30.5\n"
    );
    assert_eq!(show(&plan), ["10.10.0.53", "10.20.30.5"]);
  }
  #[test]
  fn empty() {
    let plan = Plan::new(&HashMap::new(), &Config::default());
    assert_eq!(plan.log, EMPTY);
    assert_eq!(show(&plan), EMPTY);
    assert_eq!(plan.dnsmasq_conf(), "");
  }
}
