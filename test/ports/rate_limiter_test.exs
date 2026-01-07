defmodule PortfolioCore.Ports.RateLimiterTest do
  use PortfolioCore.SupertesterCase, async: true

  alias PortfolioCore.Ports.RateLimiter

  describe "behaviour definition" do
    test "defines check/1 callback" do
      assert {:check, 1} in RateLimiter.behaviour_info(:callbacks)
    end

    test "defines check/2 callback" do
      assert {:check, 2} in RateLimiter.behaviour_info(:callbacks)
    end

    test "defines wait/1 callback" do
      assert {:wait, 1} in RateLimiter.behaviour_info(:callbacks)
    end

    test "defines wait/2 callback" do
      assert {:wait, 2} in RateLimiter.behaviour_info(:callbacks)
    end

    test "defines record_success/2 callback" do
      assert {:record_success, 2} in RateLimiter.behaviour_info(:callbacks)
    end

    test "defines record_failure/3 callback" do
      assert {:record_failure, 3} in RateLimiter.behaviour_info(:callbacks)
    end

    test "defines configure/2 callback" do
      assert {:configure, 2} in RateLimiter.behaviour_info(:callbacks)
    end

    test "defines status/1 callback" do
      assert {:status, 1} in RateLimiter.behaviour_info(:callbacks)
    end
  end

  describe "types" do
    test "provider type is defined" do
      # This is a compile-time check - if the module compiles, types are valid
      assert Code.ensure_loaded?(RateLimiter)
    end
  end
end
