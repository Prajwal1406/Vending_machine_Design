# FPGA Vending Machine Controller

A dual-clock domain FPGA design for a vending machine controller featuring an APB configuration interface, clock domain crossing (CDC) synchronizers, and a finite state machine (FSM) for transaction management.

## Key Features

- Dual clock domains: 50MHz APB interface and 100MHz FSM operation
- Finite State Machine for handling item selection, currency, dispensing, and change
- Safe asynchronous signal synchronization for user inputs and configuration
- Memory management for item costs, availability, and dispensing tracking

## Main Source Files

- `vending_top.v`: Top-level integration module
- `main_fsm.v`: Transaction processing finite state machine
- `item_memory.v`: Item cost and availability memory
- `apb_cdc.v`: APB to memory clock domain crossing bridge
- `input_cdc.v`: Asynchronous input synchronization module

## Getting Started

Clone the repository:

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

Created by [Your Name] - feel free to reach out for questions or collaborations.

