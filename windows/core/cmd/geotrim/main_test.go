package main

import (
	"context"
	"encoding/json"
	"net/netip"
	"os"
	"path/filepath"
	"testing"

	"github.com/xtls/xray-core/core"
	_ "github.com/xtls/xray-core/main/distro/all"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
)

// The router ships only the trimmed files, so the configuration it runs
// must start on them: a list a rule names and the files lack makes the core
// refuse every connect.
func TestTheTunnelsRulesLoadFromTheTrimmedData(t *testing.T) {
	full, _ := filepath.Abs("../../.assets")
	if _, err := os.Stat(filepath.Join(full, "geosite.dat")); err != nil {
		t.Skip("run windows/core/stage.sh first")
	}
	out := t.TempDir()
	domains := filepath.Join(out, "ir.json")
	if err := run(full, out, codes("PRIVATE,IR"), codes("PRIVATE,CATEGORY-IR"), domains, "CATEGORY-IR"); err != nil {
		t.Fatal(err)
	}
	for _, f := range []string{"geoip.dat", "geosite.dat"} {
		info, err := os.Stat(filepath.Join(out, f))
		if err != nil || info.Size() > 1<<20 {
			t.Fatalf("%s: %v, %d bytes", f, err, info.Size())
		}
	}
	var list struct {
		Suffix []string `json:"suffix"`
	}
	data, _ := os.ReadFile(domains)
	if err := json.Unmarshal(data, &list); err != nil || len(list.Suffix) < 50 {
		t.Fatalf("the domain list has %d names: %v", len(list.Suffix), err)
	}

	t.Setenv("XRAY_LOCATION_ASSET", out)
	built, err := config.BuildWith(context.Background(), config.Request{
		Link: "vless://11111111-2222-3333-4444-555555555555@192.0.2.10:443?type=tcp&security=none#t",
	}, func(context.Context, string) ([]netip.Addr, error) { return nil, nil }, config.RouterAdapter)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(built.Config)
	inst, err := core.StartInstance("json", raw)
	if err != nil {
		t.Fatalf("the core refused the router's rules on the trimmed data: %v", err)
	}
	_ = inst.Close()
}

func TestAListTheRulesNeedCannotBeLeftOut(t *testing.T) {
	full, _ := filepath.Abs("../../.assets")
	if _, err := os.Stat(filepath.Join(full, "geosite.dat")); err != nil {
		t.Skip("run windows/core/stage.sh first")
	}
	if err := run(full, t.TempDir(), codes("PRIVATE,NO-SUCH-LIST"), codes("PRIVATE"), "", ""); err == nil {
		t.Fatal("a missing list was not refused")
	}
}
