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

defmodule OMG.API.State.Transaction.Signed do
  @moduledoc """
  Representation of a signed transaction
  """

  alias OMG.API.Crypto
  alias OMG.API.State.Transaction

  @signature_length 65
  @type signed_tx_bytes_t() :: bitstring() | nil

  defstruct [:raw_tx, :sigs, :signed_tx_bytes]

  @type t() :: %__MODULE__{
          raw_tx: Transaction.t(),
          sigs: [Crypto.sig_t()],
          signed_tx_bytes: signed_tx_bytes_t()
        }

  def signed_hash(%__MODULE__{raw_tx: tx, sigs: sigs}) do
    tx_hash = Transaction.hash(tx)
  end

  def encode(%__MODULE__{
        raw_tx: %Transaction{inputs: [input1, input2], outputs: [output1, output2]},
        sigs: [sig1, sig2]
      }) do
    [
      input1.blknum,
      input1.txindex,
      input1.oindex,
      input2.blknum,
      input2.txindex,
      input2.oindex,
      output1.currency,
      output1.owner,
      output1.amount,
      output2.owner,
      output2.amount,
      sig1,
      sig2
    ]
    |> ExRLP.encode()
  end

  def decode(signed_tx_bytes) do
    with {:ok, tx} <- rlp_decode(signed_tx_bytes), do: reconstruct_tx(tx, signed_tx_bytes)
  end

  defp rlp_decode(line) do
    try do
      {:ok, ExRLP.decode(line)}
    rescue
      _ -> {:error, :malformed_transaction_rlp}
    end
  end

  defp reconstruct_tx(
         [
           blknum1,
           txindex1,
           oindex1,
           blknum2,
           txindex2,
           oindex2,
           cur12,
           newowner1,
           amount1,
           newowner2,
           amount2,
           sig1,
           sig2
         ],
         signed_tx_bytes
       ) do
    with :ok <- signature_length?(sig1),
         :ok <- signature_length?(sig2),
         {:ok, parsed_cur12} <- address_parse(cur12),
         {:ok, parsed_newowner1} <- address_parse(newowner1),
         {:ok, parsed_newowner2} <- address_parse(newowner2) do
      inputs = [
        %{blknum: int_parse(blknum1), txindex: int_parse(txindex1), oindex: int_parse(oindex1)},
        %{blknum: int_parse(blknum2), txindex: int_parse(txindex2), oindex: int_parse(oindex2)}
      ]

      outputs = [
        %{owner: parsed_newowner1, amount: int_parse(amount1), currency: parsed_cur12},
        %{owner: parsed_newowner2, amount: int_parse(amount2), currency: parsed_cur12}
      ]

      raw_tx = %Transaction{inputs: inputs, outputs: outputs}

      {:ok,
       %__MODULE__{
         raw_tx: raw_tx,
         sigs: [sig1, sig2],
         signed_tx_bytes: signed_tx_bytes
       }}
    end
  end

  # essentially - wrong number of fields after rlp decoding
  defp reconstruct_tx(_singed_tx, _signed_tx_bytes) do
    {:error, :malformed_transaction}
  end

  defp int_parse(int), do: :binary.decode_unsigned(int, :big)

  # necessary, because RLP handles empty string equally to integer 0
  @spec address_parse(<<>> | Crypto.address_t()) :: {:ok, Crypto.address_t()} | {:error, :malformed_address}
  defp address_parse(address)
  defp address_parse(""), do: {:ok, <<0::160>>}
  defp address_parse(<<_::160>> = address_bytes), do: {:ok, address_bytes}
  defp address_parse(_), do: {:error, :malformed_address}

  defp signature_length?(sig) when byte_size(sig) == @signature_length, do: :ok
  defp signature_length?(_sig), do: {:error, :bad_signature_length}
end
