package x509distrust

import (
	"crypto/sha256"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"errors"
	"os"
	"testing"
	"time"
)

// AAA Certificate Services expires on 2028-12-31, and so do the
// cross-certificates. A fixed time keeps the test meaningful after that.
var at = time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)

// The SPKI sha256 of the eight intermediates, as go1.26.10 lists them.
var distrusted = map[string]bool{
	"ebed6475c2c2d80fcb199f3fe8dd6e6b3ce60b77eb15d4e42c3dec0c6f5b5105": true, // EM DV TLS CA - G3B
	"43bffa19d6ef651451f6841e019931e96f6f2eaeff28ab4b6f1ce4576de2717b": true, // EM OV TLS CA - G3B
	"e0254c7fcdc265e2f0f8a428dabb75ab4ae039b4872d62f5ee57f0877d5a8a41": true, // EM EV TLS CA - G3B
	"49dd353dc2b919a3770645117d0e60c16115e7d1bc259eefe734b00ea434fe5f": true, // EM DV TLS CA - G3C
	"63ecefee431d49523bc1136c4e72d0206a477086caf606cd5cf025686c109cf8": true, // EM OV TLS CA - G3C
	"5c0660a2b164910d8ff589c18e14552e9e0ec237dcefe2cb736d41a4811f81a0": true, // EM EV TLS CA - G3C
	"ec4ffa1ad0ac88081314b7aaffef6a91f97cd57291bb5ba686c5415f5eb4f6b6": true, // EM OV CS CA - G3B
	"92c063d67e8f14db71d288e11266ffdaf69cbf115f7bab14f3bc2f68d25e0e30": true, // EM OV CS CA - G3C
}

func certs(t *testing.T, name string) []*x509.Certificate {
	t.Helper()
	b, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	var out []*x509.Certificate
	for {
		var blk *pem.Block
		blk, b = pem.Decode(b)
		if blk == nil {
			return out
		}
		c, err := x509.ParseCertificate(blk.Bytes)
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		out = append(out, c)
	}
}

func aaa(t *testing.T) *x509.Certificate {
	t.Helper()
	roots := certs(t, "aaa-certificate-services.pem")
	if len(roots) != 1 {
		t.Fatalf("want 1 root, got %d", len(roots))
	}
	return roots[0]
}

func options(root *x509.Certificate) x509.VerifyOptions {
	pool := x509.NewCertPool()
	pool.AddCert(root)
	return x509.VerifyOptions{
		Roots:       pool,
		CurrentTime: at,
		KeyUsages:   []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	}
}

// The control: the root verifies against itself, so a failure below is not
// a broken root or a wrong time.
func TestRootVerifies(t *testing.T) {
	root := aaa(t)
	if _, err := root.Verify(options(root)); err != nil {
		t.Fatal(err)
	}
}

// Each certificate is one of the eight, signed by the root and valid at the
// test's time. So Verify can only reject it because the toolchain distrusts
// its key.
func TestEmudhraIntermediatesDistrusted(t *testing.T) {
	root := aaa(t)
	cs := certs(t, "emudhra-cross-signed.pem")
	if len(cs) != len(distrusted) {
		t.Fatalf("want %d certificates, got %d", len(distrusted), len(cs))
	}
	seen := map[string]bool{}
	for _, c := range cs {
		name := c.Subject.CommonName
		sum := sha256.Sum256(c.RawSubjectPublicKeyInfo)
		spki := hex.EncodeToString(sum[:])
		if !distrusted[spki] || seen[spki] {
			t.Fatalf("%s: SPKI sha256 %s is not one of the eight, or appears twice", name, spki)
		}
		seen[spki] = true
		if err := c.CheckSignatureFrom(root); err != nil {
			t.Fatalf("%s: not signed by %s: %v", name, root.Subject.CommonName, err)
		}
		if at.Before(c.NotBefore) || at.After(c.NotAfter) {
			t.Fatalf("%s: not valid at %s", name, at)
		}
		_, err := c.Verify(options(root))
		var ce x509.CertificateInvalidError
		if !errors.As(err, &ce) || ce.Reason != x509.NoValidChains {
			t.Errorf("%s: want NoValidChains, got %v. The Go in use still trusts this key; move the toolchain line in go.mod to go1.26.10 or later.", name, err)
		}
	}
}
