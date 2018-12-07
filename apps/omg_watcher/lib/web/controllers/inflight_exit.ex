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

defmodule OMG.Watcher.Web.Controller.InFlightExit do
  @moduledoc """
  Operations related to in-flight transaction.
  """

  use OMG.Watcher.Web, :controller
  use PhoenixSwagger

  alias OMG.Watcher.Web.View
  alias OMG.Watcher.DB


  @doc """
  Retrieves available piggybacks.
  """
  def get_available_piggybacks(conn, _params) do

    ifes =
      ExitProcessor.get_in_flight_exits()
      |> remove_included_ifes()

    render(conn, View.InFlightExit, :available_piggybacks, ifes: ifes)
  end

  defp remove_included_ifes(ifes) do
    tx_hashes =
      Map.keys(ifes)
      |> DB.Transaction.get()
      |> Enum.map(fn tx -> tx.txhash end)

    ifes
    |> Map.drop(tx_hashes)
  end

  #  TODO swagger
end
