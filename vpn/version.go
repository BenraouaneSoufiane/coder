package vpn

import (
	"fmt"
	"strconv"
	"strings"

	"golang.org/x/xerrors"
)

// CurrentSupportedVersions is the list of versions supported by this
// implementation of the VPN RPC protocol.
var CurrentSupportedVersions = RPCVersionList{
	Versions: []RPCVersion{
		// 1.1 adds telemetry fields to StartRequest:
		// - device_id: Coder Desktop device ID
		// - device_os: Coder Desktop OS information
		// - coder_desktop_version: Coder Desktop version
		// 1.2 adds network related information to Agent:
		// - last_ping:
		//   - latency: RTT of the most recently sent ping
		//   - did_p2p: Whether the last ping was sent over P2P
		//   - preferred_derp: The server that DERP relayed connections are
		//                     using, if they're not using P2P.
		//   - preferred_derp_latency: The latency to the preferred DERP
		// 1.3 adds:
		// - tunnel_use_soft_net_isolation to the StartRequest
		{Major: 1, Minor: 3},
	},
}

// RPCVersion represents a single version of the RPC protocol. Any given version
// is expected to be backwards compatible with all previous minor versions on
// the same major version.
//
// e.g. RPCVersion{2, 3} is backwards compatible with RPCVersion{2, 2} but is
// not backwards compatible with RPCVersion{1, 2}.
type RPCVersion struct {
	Major uint64 `json:"major"`
	Minor uint64 `json:"minor"`
}

// ParseRPCVersion parses a version string in the format "major.minor" into a
// RPCVersion.
func ParseRPCVersion(str string) (RPCVersion, error) {
	split := strings.Split(str, ".")
	if len(split) != 2 {
		return RPCVersion{}, xerrors.Errorf("invalid version string: %s", str)
	}
	major, err := strconv.ParseUint(split[0], 10, 64)
	if err != nil {
		return RPCVersion{}, xerrors.Errorf("invalid version string: %s", str)
	}
	if major == 0 {
		return RPCVersion{}, xerrors.Errorf("invalid version string: %s", str)
	}
	minor, err := strconv.ParseUint(split[1], 10, 64)
	if err != nil {
		return RPCVersion{}, xerrors.Errorf("invalid version string: %s", str)
	}
	return RPCVersion{Major: major, Minor: minor}, nil
}

func (v RPCVersion) String() string {
	return fmt.Sprintf("%d.%d", v.Major, v.Minor)
}

// IsCompatibleWith returns the lowest version that is compatible with both
// versions. If the versions are not compatible, the second return value will be
// false.
func (v RPCVersion) IsCompatibleWith(other RPCVersion) (RPCVersion, bool) {
	if v.Major != other.Major {
		return RPCVersion{}, false
	}
	// The lowest minor version from the two versions should be returned.
	if v.Minor < other.Minor {
		return v, true
	}
	return other, true
}

// RPCVersionList represents a list of RPC versions supported by a RPC peer. An
type RPCVersionList struct {
	Versions []RPCVersion `json:"versions"`
}

// ParseRPCVersionList parses a version string in the format
// "major.minor,major.minor" into a RPCVersionList.
func ParseRPCVersionList(str string) (RPCVersionList, error) {
	split := strings.Split(str, ",")
	versions := make([]RPCVersion, len(split))
	for i, v := range split {
		version, err := ParseRPCVersion(v)
		if err != nil {
			return RPCVersionList{}, xerrors.Errorf("invalid version list: %s", str)
		}
		versions[i] = version
	}
	vl := RPCVersionList{Versions: versions}
	err := vl.Validate()
	if err != nil {
		return RPCVersionList{}, xerrors.Errorf("invalid parsed version list %q: %w", str, err)
	}
	return vl, nil
}

func (vl RPCVersionList) String() string {
	versionStrings := make([]string, len(vl.Versions))
	for i, v := range vl.Versions {
		versionStrings[i] = v.String()
	}
	return strings.Join(versionStrings, ",")
}

// Validate returns an error if the version list is not sorted or contains
// duplicate major versions.
func (vl RPCVersionList) Validate() error {
	if len(vl.Versions) == 0 {
		return xerrors.New("no versions")
	}
	for i := 0; i < len(vl.Versions); i++ {
		if vl.Versions[i].Major == 0 {
			return xerrors.Errorf("invalid version: %s", vl.Versions[i].String())
		}
		if i > 0 && vl.Versions[i-1].Major == vl.Versions[i].Major {
			return xerrors.Errorf("duplicate major version: %d", vl.Versions[i].Major)
		}
		if i > 0 && vl.Versions[i-1].Major > vl.Versions[i].Major {
			return xerrors.Errorf("versions are not sorted")
		}
	}
	return nil
}

// IsCompatibleWith returns the lowest version that is compatible with both
// version lists. If the versions are not compatible, the second return value
// will be false.
func (vl RPCVersionList) IsCompatibleWith(other RPCVersionList) (RPCVersion, bool) {
	bestVersion := RPCVersion{}
	for _, v1 := range vl.Versions {
		for _, v2 := range other.Versions {
			if v1.Major == v2.Major && v1.Major > bestVersion.Major {
				v, ok := v1.IsCompatibleWith(v2)
				if ok {
					bestVersion = v
				}
			}
		}
	}
	if bestVersion.Major == 0 {
		return bestVersion, false
	}
	return bestVersion, true
}
