program counter.aleo {
    mapping count: u64 => u64;
    
    transition initialize() {
        return;
    }
    final initialize() {
        Mapping::set(count, 0u64);
    }
    transition increment() {
        return;
    }
    final increment() {
        let n: u64 = Mapping::get_or_use(count, 0u64);
        Mapping::set(count, (n + 1u64));
    }
    transition get() -> public u64 {
        return Mapping::get_or_use(count, 0u64);
    }
}