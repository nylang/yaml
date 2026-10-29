// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of YamlDom;

@test(tag = "heap-initialization")
func test_yaml_dom_frame_initializes_poisoned_raw_storage() {
  let size: int64 = sizeof(YamlDomFrame) as int64;
  let raw: *mut int8 = _nyra_malloc(size, 8 as int64);
  AssertTrue(raw != ptr<int8>.null());
  if raw == ptr<int8>.null() {
    return;
  }

  memset(raw as *mut uint8, 85u8, size as uintptr);
  let durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let frame: *mut YamlDomFrame = yaml_dom_frame_initialize(raw, durable, true, ptr<YamlDomFrame>.null());
  unsafe {
    AssertTrue((*frame).is_map);
    AssertEqI32((*frame).map.Len(), 0);
    AssertEqI32((*frame).seq.Len(), 0);
    AssertEqString((*frame).pending_key, "");
    AssertTrue(! (*frame).has_pending_key);
    AssertTrue((*frame).prev == ptr<YamlDomFrame>.null());
  }

  yaml_dom_frame_free(frame);
}
