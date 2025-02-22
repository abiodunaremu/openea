# FxChartAI Algorithm Trading EA

FxChartAI Algorithm Trading EA is an open-source Expert Advisor (EA) for MetaTrader 5, designed to trade using signals received from FxChartAI. The EA processes CSV files containing trading signals and implements a structured trading checklist for making market decisions. This project is free to use for both personal and commercial purposes, and we encourage contributions to help improve the algorithm toward achieving 100% accurate trade decisions.

![openea-all-positions_jpg](https://github.com/user-attachments/assets/87e55224-ce66-4869-a4f2-e658e7052973)


## Features

- **CSV Data Handling**  
  - Reads and processes two CSV files: `datasets/signal_dataset_gbpusd_m10.csv` and `datasets/signal_dataset_gbpusd_h1.csv`
  - CSV headers include:
    - `Datetime` (timestamp of the signal)
    - `Position` (0 = Buy, 1 = Sell, 2 = None)
    - `Signal` (0 = High Trend, 1 = Low Trend, 2 = No Trend)
  - The EA waits 3 minutes after a new candle is formed and confirms that the CSV has been updated before proceeding.

- **Trading Logic**  
  - **Trend Confirmation:**  
    - For M10: Checks for at least three consecutive signals of ‘0’ (High Trend) and/or ‘1’ (Low Trend).  
    - For H1: Checks for at least three occurrences of the same position’s signal (0 or 1) without interruption.
  - **Candle Tail & Trendline Analysis:**  
    - Confirms trade entries using candle tail and trendline analysis.
    - Implements logic for calculating candle tails and trendlines to support buy/sell decisions.
  - **Trade Execution:**  
    - Places pending orders (Buy/Sell Stops) with price levels derived from candle sizes.
    - Executes market orders immediately when conditions are met.
  - **Timeframe Consideration:**  
    - M10 signals are treated as short-term trades (tight stop loss & take profit).  
    - H1 signals are treated as long-term trades (flexible stop loss & take profit).
  - **Trend Reversal Management:**  
    - Exits trades if the CSV signals no longer support the current position and an opposing trendline is detected.
    - Adjusts pending orders if the trend unexpectedly continues.
  - **Take Profit & Stop Loss Strategy:**  
    - For Buy trades: Sets take profit at the highest high of the previous 200 candles.
    - For Sell trades: Sets take profit at the lowest low of the previous 200 candles.
    - Considers sudden volatility and price spikes.

- **Risk Management & Logging**  
  - Configurable lot sizes, stop-loss, and take-profit levels.
  - Comprehensive error handling for file reading, order execution, and trend analysis.
  - Detailed logging messages to help with debugging and tracking trading decisions.

## Files Included

- **fxchartai_openea.mq5**  
  The main EA source code implementing the trading logic based on FxChartAI signals.

- **datasets/signal_dataset_gbpusd_m10.csv**  
  Example CSV dataset for GBP/USD signals on the M10 timeframe.

- **datasets/signal_dataset_gbpusd_h1.csv**  
  Example CSV dataset for GBP/USD signals on the H1 timeframe.

## Getting Started

1. **Installation:**
   - Clone or download this repository.
   - Place the `fxchartai_openea.mq5` file into your `MQL5/Experts` directory.
   - Ensure the CSV files are located in the `datasets` folder relative to your MetaTrader 5 data directory.

2. **Compilation:**
   - Open MetaEditor.
   - Open `fxchartai_openea.mq5` and compile the EA.
   - Resolve any dependencies if prompted.

3. **Usage:**
   - Attach the EA to a chart on either the M10 or H1 timeframe.
   - Configure input parameters (e.g., lot size, stop loss, take profit, confidence level).
   - The EA will read the CSV files, process the signals, and execute trades based on the implemented logic.
   - Monitor the Experts log for messages regarding trade decisions and error handling.

## Contributing

We welcome contributions from the community to improve the FxChartAI Algorithm Trading EA. If you have ideas or improvements that can help the algorithm reach 100% accurate trade decisions, please:

- Fork this repository.
- Create a feature branch and implement your changes.
- Submit a pull request with detailed information about your changes.
- Open issues for any bugs or feature requests.

## Disclaimer

**Important:** The owners of this repository, including FxChartAI, are not responsible for any outcomes or losses incurred through the use of this code. Use this EA at your own risk. This disclaimer is also included in the MIT License provided with this project.

## License

This project is released under the [MIT License](LICENSE). It is free to use for both personal and commercial purposes.

## References & Additional Information

- **Official Website:** [fxchartai.com](https://fxchartai.com)
- **My Journey into Training Transformer Models: Lessons and Insights**  
  [Read the article](https://abiodunaremung.medium.com/my-journey-into-training-transformer-models-lessons-and-insights-40f224273f2f)
- **Lessons Learned from Fine-Tuning a Transformer Model on Forex Data**  
  [Read the article](https://abiodunaremung.medium.com/lessons-learned-from-fine-tuning-a-transformer-model-on-forex-data-d1d25e98bba0)
- **FxChartAI ABT: The Final Piece on AI-Driven Forex Analysis Journey**  
  [Read the article](https://abiodunaremung.medium.com/fxchartai-abt-the-final-piece-on-ai-driven-forex-analysis-journey-848466aca457)

## Final Notes

This EA provides a robust starting point for algorithmic trading based on FxChartAI signals. The project structure is designed to encourage community contributions and improvements. Enjoy trading and happy coding!

