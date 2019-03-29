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

defmodule OMG.Watcher.Supervisor do
  @moduledoc """
  Supervises the remainder (i.e. all except the `Watcher.BlockGetter` + `OMG.State` pair, supervised elsewhere)
  of the Watcher app
  """
  use Supervisor
  use OMG.LoggerExt

  alias OMG.Watcher

  if Application.get_env(:omg_watcher, :sql_sandbox) do
    defmodule Sandbox do
      @moduledoc false
      use GenServer
      alias Ecto.Adapters.SQL

      def start_link(_args) do
        GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
      end

      def init(stack) do
        :ok = SQL.Sandbox.checkout(Watcher.DB.Repo, ownership_timeout: 180_000)
        SQL.Sandbox.mode(Watcher.DB.Repo, {:shared, self()})
        {:ok, stack}
      end
    end
  end

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children =
      [
        # Start the Ecto repository
        %{
          id: Watcher.DB.Repo,
          start: {Watcher.DB.Repo, :start_link, []},
          type: :supervisor
        }
      ] ++
        if(Application.get_env(:omg_watcher, :sql_sandbox), do: [{__MODULE__.Sandbox, []}], else: []) ++
        [
          %{
            id: Watcher.SyncSupervisor,
            start: {Watcher.SyncSupervisor, :start_link, []},
            restart: :permanent,
            type: :supervisor
          },
          # Start workers
          {Watcher.Eventer, []},
          # Start the endpoint when the application starts
          %{
            id: Watcher.Web.Endpoint,
            start: {Watcher.Web.Endpoint, :start_link, []},
            type: :supervisor
          }
        ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end
