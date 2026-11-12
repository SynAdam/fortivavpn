// Copyright (C) 2026 NimusAI. GPL-3.0-or-later, with the additional terms
// under section 7 in LICENSING.md.

// Command geotrim cuts the routing data down to the lists the tunnel's rules
// name (config.routing): geoip "private" and "ir", geosite "private" and
// "category-ir". The full files are 27 MB together and a router has a few
// tens of megabytes of flash; the lists the rules use are a few hundred
// kilobytes. It can also write one geosite list as JSON, which the browser
// extension builds its "go direct" list from.
//
//	geotrim -in DIR -out DIR                 trimmed geoip.dat and geosite.dat in DIR
//	geotrim -in DIR -domains FILE            CATEGORY-IR's domains as JSON
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"google.golang.org/protobuf/proto"

	"github.com/xtls/xray-core/common/geodata"
)

func main() {
	in := flag.String("in", "", "directory with the full geoip.dat and geosite.dat")
	out := flag.String("out", "", "directory to write the trimmed files to")
	ips := flag.String("ip", "PRIVATE,IR", "geoip lists to keep")
	sites := flag.String("site", "PRIVATE,CATEGORY-IR", "geosite lists to keep")
	domains := flag.String("domains", "", "write one geosite list's domains to this JSON file")
	domainsCode := flag.String("domains-code", "CATEGORY-IR", "the geosite list -domains writes")
	flag.Parse()
	if *in == "" || (*out == "" && *domains == "") {
		fmt.Fprintln(os.Stderr, "usage: geotrim -in DIR (-out DIR | -domains FILE)")
		os.Exit(2)
	}
	if err := run(*in, *out, codes(*ips), codes(*sites), *domains, strings.ToUpper(*domainsCode)); err != nil {
		fmt.Fprintln(os.Stderr, "geotrim:", err)
		os.Exit(1)
	}
}

func codes(s string) map[string]bool {
	out := map[string]bool{}
	for _, c := range strings.Split(s, ",") {
		if c = strings.ToUpper(strings.TrimSpace(c)); c != "" {
			out[c] = true
		}
	}
	return out
}

func run(in, out string, ips, sites map[string]bool, domainsFile, domainsCode string) error {
	var siteList geodata.GeoSiteList
	if err := load(filepath.Join(in, "geosite.dat"), &siteList); err != nil {
		return err
	}
	if domainsFile != "" {
		if err := writeDomains(&siteList, domainsCode, domainsFile); err != nil {
			return err
		}
	}
	if out == "" {
		return nil
	}
	var ipList geodata.GeoIPList
	if err := load(filepath.Join(in, "geoip.dat"), &ipList); err != nil {
		return err
	}

	keptIP := &geodata.GeoIPList{}
	for _, e := range ipList.Entry {
		if ips[strings.ToUpper(e.Code)] {
			keptIP.Entry = append(keptIP.Entry, e)
		}
	}
	keptSite := &geodata.GeoSiteList{}
	for _, e := range siteList.Entry {
		if sites[strings.ToUpper(e.Code)] {
			keptSite.Entry = append(keptSite.Entry, e)
		}
	}
	if err := allFound(ips, len(keptIP.Entry), "geoip"); err != nil {
		return err
	}
	if err := allFound(sites, len(keptSite.Entry), "geosite"); err != nil {
		return err
	}
	if err := os.MkdirAll(out, 0o755); err != nil {
		return err
	}
	if err := save(filepath.Join(out, "geoip.dat"), keptIP); err != nil {
		return err
	}
	return save(filepath.Join(out, "geosite.dat"), keptSite)
}

// allFound refuses a trimmed file that lacks a list a rule names: the core
// would refuse every configuration with that rule, on the router.
func allFound(want map[string]bool, found int, kind string) error {
	if found != len(want) {
		var names []string
		for c := range want {
			names = append(names, c)
		}
		sort.Strings(names)
		return fmt.Errorf("%s.dat holds %d of the lists %v", kind, found, names)
	}
	return nil
}

// writeDomains writes the list's plain and full domains. Regular expressions
// and keywords are left out: a browser's proxy script matches names by their
// suffix, and a wrong keyword match would send a foreign site direct.
func writeDomains(list *geodata.GeoSiteList, code, file string) error {
	var suffix, full []string
	found := false
	for _, e := range list.Entry {
		if strings.ToUpper(e.Code) != code {
			continue
		}
		found = true
		for _, d := range e.Domain {
			switch d.Type {
			case geodata.Domain_Domain:
				suffix = append(suffix, strings.ToLower(d.Value))
			case geodata.Domain_Full:
				full = append(full, strings.ToLower(d.Value))
			}
		}
	}
	if !found {
		return fmt.Errorf("geosite.dat has no list %s", code)
	}
	sort.Strings(suffix)
	sort.Strings(full)
	data, err := json.Marshal(map[string]any{"code": code, "suffix": dedupe(suffix), "full": dedupe(full)})
	if err != nil {
		return err
	}
	return os.WriteFile(file, append(data, '\n'), 0o644)
}

func dedupe(in []string) []string {
	out := []string{}
	for i, s := range in {
		if i == 0 || s != in[i-1] {
			out = append(out, s)
		}
	}
	return out
}

func load(path string, m proto.Message) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := proto.Unmarshal(data, m); err != nil {
		return fmt.Errorf("%s: %w", path, err)
	}
	return nil
}

func save(path string, m proto.Message) error {
	data, err := proto.Marshal(m)
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}
