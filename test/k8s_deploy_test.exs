defmodule K8SDeployTest do
  use ExUnit.Case
  doctest K8SDeploy

  test "greets the world" do
    assert K8SDeploy.hello() == :world
  end
end
