# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.ExitProcessor.Fixtures do
  use ExUnitFixtures.FixtureModule

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction
  alias OMG.API.Utxo
  alias OMG.Watcher.ExitProcessor.Core
  alias OMG.Watcher.ExitProcessor.InFlightExitInfo
  require Utxo

  @eth Crypto.zero_address()
  @not_eth <<1::size(160)>>

  @utxo_pos1 Utxo.position(1, 0, 0)
  @utxo_pos2 Utxo.Position.decode(10_000_000_001)

  deffixture tokens() do
    {@eth, @not_eth}
  end

  deffixture utxo_positions() do
    [@utxo_pos1, @utxo_pos2]
  end

  deffixture transactions() do
    [
      %Transaction{
        inputs: [%{blknum: 1, txindex: 1, oindex: 0}, %{blknum: 1, txindex: 2, oindex: 1}],
        outputs: [
          %{owner: "alicealicealicealice", currency: @eth, amount: 1},
          %{owner: "carolcarolcarolcarol", currency: @eth, amount: 2}
        ]
      },
      %Transaction{
        inputs: [%{blknum: 2, txindex: 1, oindex: 0}, %{blknum: 2, txindex: 2, oindex: 1}],
        outputs: [
          %{owner: "alicealicealicealice", currency: @eth, amount: 1},
          %{owner: "carolcarolcarolcarol", currency: @eth, amount: 2}
        ]
      }
    ]
  end

  deffixture processor_empty() do
    {:ok, empty} = Core.init([])
    empty
  end

  # events is whatever `OMG.Eth` would feed into the `OMG.Watcher.ExitProcessor`, via `OMG.API.EthereumEventListener`
  deffixture events(alice) do
    %{addr: alice} = alice

    [
      %{amount: 10, currency: @eth, owner: alice, utxo_pos: Utxo.Position.encode(@utxo_pos1), eth_height: 2},
      %{amount: 9, currency: @not_eth, owner: alice, utxo_pos: Utxo.Position.encode(@utxo_pos2), eth_height: 4}
    ]
  end

  deffixture ife_events(transactions, alice) do
    %{addr: alice} = alice
    [tx1_hash, tx2_hash] = transactions |> Enum.map(&Transaction.hash/1)

    [
      %{tx_hash: tx1_hash, initiator: alice},
      %{tx_hash: tx2_hash, initiator: alice}
    ]
  end

  # extracts the mocked responses of the `Eth.RootChain.get_exit` for the exit events
  # all exits active (owner non-zero). This is the auxiliary, second argument that's fed into `new_exits`
  deffixture contract_statuses(events) do
    events
    |> Enum.map(fn %{amount: amount, currency: currency, owner: owner} -> {owner, currency, amount} end)
  end

  deffixture ife_contract_data(transactions, alice) do
    %{priv: alice_priv} = alice

    signatures =
      transactions
      |> Enum.map(&Transaction.sign(&1, [alice_priv, alice_priv]))
      |> Enum.map(& &1.sigs)

    tx_bytes = transactions |> Enum.map(&Transaction.encode/1)

    Enum.zip([tx_bytes, signatures, List.duplicate(0, length(tx_bytes))])
  end

  deffixture ifes(ife_events, ife_contract_data) do
    Enum.zip(ife_events, ife_contract_data)
    |> Enum.map(fn {ife_event, {tx_bytes, signatures, timestamp}} ->
      {:ok, raw_tx, []} = Transaction.decode(tx_bytes)

      signed_tx = %Transaction.Signed{
        raw_tx: raw_tx,
        sigs: signatures
      }

      {ife_event.tx_hash, %InFlightExitInfo{tx: signed_tx, timestamp: timestamp}}
    end)
  end

  deffixture processor_filled(processor_empty, events, contract_statuses) do
    {state, _} = Core.new_exits(processor_empty, events, contract_statuses)
    state
  end
end
