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

defmodule OMG.BlockQueueAPI do
  @moduledoc """
  Interface to cast a new block for publishing

  NOTE: same comment on pub-sub as `OMG.EventerAPI`
  """

  alias OMG.Block

  @doc """
  Enqueues child chain block to be submitted to Ethereum
  Casts (only when `OMG.API.BlockQueue.Server` is started; if not, it is a noop)
  """
  @spec enqueue_block(Block.t()) :: :ok
  def enqueue_block(block) do
    GenServer.cast(OMG.API.BlockQueue.Server, {:enqueue_block, block})
  end
end
