package agentsdk_test

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"tailscale.com/tailcfg"

	"cdr.dev/slog/sloggers/slogtest"
	"github.com/coder/coder/v2/codersdk/agentsdk"
	"github.com/coder/coder/v2/testutil"
)

func TestStreamAgentReinitEvents(t *testing.T) {
	t.Parallel()

	t.Run("transmitted events are received", func(t *testing.T) {
		t.Parallel()

		eventToSend := agentsdk.ReinitializationEvent{
			WorkspaceID: uuid.New(),
			Reason:      agentsdk.ReinitializeReasonPrebuildClaimed,
		}

		events := make(chan agentsdk.ReinitializationEvent, 1)
		events <- eventToSend

		transmitCtx := testutil.Context(t, testutil.WaitShort)
		transmitErrCh := make(chan error, 1)
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			transmitter := agentsdk.NewSSEAgentReinitTransmitter(slogtest.Make(t, nil), w, r)
			transmitErrCh <- transmitter.Transmit(transmitCtx, events)
		}))
		defer srv.Close()

		requestCtx := testutil.Context(t, testutil.WaitShort)
		req, err := http.NewRequestWithContext(requestCtx, "GET", srv.URL, nil)
		require.NoError(t, err)
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		defer resp.Body.Close()

		receiveCtx := testutil.Context(t, testutil.WaitShort)
		receiver := agentsdk.NewSSEAgentReinitReceiver(resp.Body)
		sentEvent, receiveErr := receiver.Receive(receiveCtx)
		require.Nil(t, receiveErr)
		require.Equal(t, eventToSend, *sentEvent)
	})

	t.Run("doesn't transmit events if the transmitter context is canceled", func(t *testing.T) {
		t.Parallel()

		eventToSend := agentsdk.ReinitializationEvent{
			WorkspaceID: uuid.New(),
			Reason:      agentsdk.ReinitializeReasonPrebuildClaimed,
		}

		events := make(chan agentsdk.ReinitializationEvent, 1)
		events <- eventToSend

		transmitCtx, cancelTransmit := context.WithCancel(testutil.Context(t, testutil.WaitShort))
		cancelTransmit()
		transmitErrCh := make(chan error, 1)
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			transmitter := agentsdk.NewSSEAgentReinitTransmitter(slogtest.Make(t, nil), w, r)
			transmitErrCh <- transmitter.Transmit(transmitCtx, events)
		}))

		defer srv.Close()

		requestCtx := testutil.Context(t, testutil.WaitShort)
		req, err := http.NewRequestWithContext(requestCtx, "GET", srv.URL, nil)
		require.NoError(t, err)
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		defer resp.Body.Close()

		receiveCtx := testutil.Context(t, testutil.WaitShort)
		receiver := agentsdk.NewSSEAgentReinitReceiver(resp.Body)
		sentEvent, receiveErr := receiver.Receive(receiveCtx)
		require.Nil(t, sentEvent)
		require.ErrorIs(t, receiveErr, io.EOF)
	})

	t.Run("does not receive events if the receiver context is canceled", func(t *testing.T) {
		t.Parallel()

		eventToSend := agentsdk.ReinitializationEvent{
			WorkspaceID: uuid.New(),
			Reason:      agentsdk.ReinitializeReasonPrebuildClaimed,
		}

		events := make(chan agentsdk.ReinitializationEvent, 1)
		events <- eventToSend

		transmitCtx := testutil.Context(t, testutil.WaitShort)
		transmitErrCh := make(chan error, 1)
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			transmitter := agentsdk.NewSSEAgentReinitTransmitter(slogtest.Make(t, nil), w, r)
			transmitErrCh <- transmitter.Transmit(transmitCtx, events)
		}))
		defer srv.Close()

		requestCtx := testutil.Context(t, testutil.WaitShort)
		req, err := http.NewRequestWithContext(requestCtx, "GET", srv.URL, nil)
		require.NoError(t, err)
		resp, err := http.DefaultClient.Do(req)
		require.NoError(t, err)
		defer resp.Body.Close()

		receiveCtx, cancelReceive := context.WithCancel(context.Background())
		cancelReceive()
		receiver := agentsdk.NewSSEAgentReinitReceiver(resp.Body)
		sentEvent, receiveErr := receiver.Receive(receiveCtx)
		require.Nil(t, sentEvent)
		require.ErrorIs(t, receiveErr, context.Canceled)
	})
}

func TestRewriteDERPMap(t *testing.T) {
	t.Parallel()
	// This test ensures that RewriteDERPMap mutates built-in DERPs with the
	// client access URL.
	dm := &tailcfg.DERPMap{
		Regions: map[int]*tailcfg.DERPRegion{
			1: {
				EmbeddedRelay: true,
				RegionID:      1,
				Nodes: []*tailcfg.DERPNode{{
					HostName: "bananas.org",
					DERPPort: 1,
				}},
			},
		},
	}
	parsed, err := url.Parse("https://coconuts.org:44558")
	require.NoError(t, err)
	client := agentsdk.New(parsed)
	client.RewriteDERPMap(dm)
	region := dm.Regions[1]
	require.True(t, region.EmbeddedRelay)
	require.Len(t, region.Nodes, 1)
	node := region.Nodes[0]
	require.Equal(t, "coconuts.org", node.HostName)
	require.Equal(t, 44558, node.DERPPort)
}
