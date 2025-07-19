object "AgentProxy" {
  code {
    datacopy(0, dataoffset("runtime"), datasize("runtime"))
    return(0, datasize("runtime"))
  }

  object "runtime" {
    code {
      let impl := 0x0000000000000000000000001234567890abcdef1234567890abcdef12345678

      // copy full calldata -> mem[0..calldatasize)
      let cdsz := calldatasize()
      calldatacopy(0, 0, cdsz)

      // STATICCALL to Impl with that buffer
      pop(staticcall(gas(), impl, 0, cdsz, 0, 0))

      // bubble up return data
      returndatacopy(0, 0, returndatasize())
      return(0, returndatasize())
    }
  }
}
