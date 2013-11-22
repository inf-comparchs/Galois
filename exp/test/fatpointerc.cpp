#include "Galois/Runtime/RemotePointer.h"

int main() {
  Galois::Runtime::fatPointer ptr;
  
  Galois::Runtime::Lockable* oldobj = ptr.getObj();
  for (uint32_t h = 0; h < 0x0000FFFF; h += 3) {
    ptr.setHost(h);
    assert(ptr.getHost() == h);
    assert(ptr.getObj() == oldobj);
  }

//Misc error checking
static_assert(std::is_trivially_copyable<fatPointer>::value, "fatPointer should be trivially serializable");
static_assert(std::is_trivially_copyable<gptr<int>>::value, "RemotePointer should be trivially serializable");


  return 0;
}
