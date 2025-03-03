# FxChartAI Algorithm Trading EA

FxChartAI Algorithm Trading EA is an open-source Expert Advisor (EA) for MetaTrader 5, designed for algorithmic trading using signals received from FxChartAI. The EA processes market signals from FxChartAI and implements a structured trading checklist for making trading decisions. It now integrates live signal data via API calls (with fallback CSV test mode) and includes advanced trend confirmation, candle tail/trendline analysis, dynamic order management, and robust error handling. This project is free to use for both personal and commercial purposes, and we encourage contributions to help improve the algorithm toward achieving 100% accurate trade decisions.

![openea-all-positions_jpg](https://github.com/user-attachments/assets/87e55224-ce66-4869-a4f2-e658e7052973)


## Features

- **API & CSV Signal Integration:**  
  - Retrieves live signals from FxChartAI API via GET requests.
  - Fallback support for CSV-based signals in test mode.
  - Signals include `position` (0 = Buy, 1 = Sell, 2 = None), and `signal` (e.g., weight).

- **Multi-Timeframe Analysis:**  
  - Processes both M10 and H1 data.
  - Confirms trends using consecutive signal checks.
  - Uses advanced candle tail and trendline analysis for trade confirmation.

- **Dynamic Order Management:**  
  - Places pending orders (Buy/Sell Stops) or executes market orders based on signal analysis.
  - Manages open orders and trend reversals with robust error handling.

- **Configurable Parameters:**  
  - Lot sizes, Stop Loss, Take Profit, confidence levels, and mode selection (test vs. live) are fully configurable.

- **Trading Logic**  
  - **Trend Confirmation:**  
    - Checks for at least `ConfidenceLevel` consecutive signals of ‘0’ (High Trend) and/or ‘1’ (Low Trend).
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
    - Exits trades if the signals no longer support the current position and an opposing trendline is detected.
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

- **datasets/Feb_2025/signal_dataset_gbpusd_m10.csv**  
  February 2025 CSV dataset for GBP/USD FxChartAI signals on the M10 timeframe.

- **datasets/Feb_2025/signal_dataset_gbpusd_h1.csv**  
  February 2025 CSV dataset for GBP/USD FxChartAI signals on the H1 timeframe.

- **include/JAson.mqh**  
  Library used by EA to process live data.

- **reports/v1_1/feb2025default/ReportTester-v1_gbpusd_feb2025.html**  
  Example Strategy Tester report from running FxChartAI OpenEA with default parameters on the February 2025 signal dataset

## Getting Started

### No Code Setup Instructions
These steps do not require editing code and are for setting up your environment to run the EA.

1. **Download Prebuilt EA**
   - Download the latest `.ex5` file from the [Releases](https://github.com/abiodunaremu/openea/releases) page.

2. **Download dependencies:**
   - Visit [https://github.com/abiodunaremu/openea](https://github.com/abiodunaremu/openea) and download the repository as a ZIP file.

3. **File Placement:**
   - Open MetaTrader 5 → File → Open Data Folder.
   - Place `fxchartai_openea.ex5` in your MetaTrader 5 `Experts` folder.  
     *(Typically located at: `MQL5/Experts` in your MetaTrader data directory.)*
   - Place the `datasets` folder (with test CSV files) in the data directory (usually located at `Tester/.../MQL5/Files`) as required (this is used only if running in test mode).

4. **Include Dependencies:**
   - Ensure that the JAson.mqh file (downloaded per [JAson.mqh article](https://www.mql5.com/en/articles/14108)) is placed in your `MQL5\Include` folder.

### Code Setup Instructions
For users familiar with MetaEditor or who wish to compile and customize the EA code.

1. **Download or Clone the Repository:**
   - Visit [https://github.com/abiodunaremu/openea](https://github.com/abiodunaremu/openea) and download the repository as a ZIP file or clone it using Git.

2. **Open MetaEditor:**
   - Launch MetaEditor from your MetaTrader 5 platform.

3. **File Placement:**
   - Place `fxchartai_openea.mq5` in your MetaTrader 5 `Experts` folder.  
     *(Typically located at: `MQL5/Experts` in your MetaTrader data directory.)*
   - Place the `datasets` folder (with sample CSV files) in the data directory (usually located at `Tester/.../MQL5/Files`) as required (this is used only if running in test mode).

4. **Include Dependencies:**
   - Ensure that the JAson.mqh file (downloaded per [JAson.mqh article](https://www.mql5.com/en/articles/14108)) is placed in your `MQL5\Include` folder.

5. **Open the EA File:**
   - In MetaEditor, navigate to `File -> Open` and select `fxchartai_openea.mq5` from the Experts folder.

6. **Review and Customize Inputs:**
   - The EA has configurable input parameters at the top of the code (e.g., `LotSize`, `StopLossPips`, `TakeProfitPips`, `confidence`, `MaxDataSize`, `mode`, and `maxAttempts`).  
   - Adjust these parameters and the code base to suit your trading strategy.

7. **Compile the EA:**
   - Click the `Compile` button in MetaEditor. Ensure that there are no errors.
   - If errors occur, verify that JAson.mqh is correctly placed and that any dependencies are resolved.

### Usage

1. **Enable WebRequest (Live Mode Only)**
   - In MetaTrader 5, go to Tools → Options → Expert Advisors.
   - Check "Allow WebRequest for listed URL".
   - Add the URL: https://chartapi.fxchartai.com to the list.
   - Run in Strategy Tester (Test Mode)
    
2. **Backtesting**
   - Open the Strategy Tester in MetaTrader 5.
   - Select the FxChartAI_OpenEA EA from the Experts dropdown.
   - Set the mode parameter to 0 (test mode is recommended) to use CSV-based signals or 1 to pull signal data using API.
   - Ensure the CSV files (test mode) are available in the correct `MQL5/Files` directory. The directory is usually clean up by Strategy Tester when the EA is updated.
   - Configure your testing parameters (date range, initial deposit, etc.).
   - Click "Start" to run the EA in the Strategy Tester.

3. **Real-time trading**
   - In MetaTrader 5, open a chart for GBP/USD.
   - Drag the FxChartAI OpenEA from the Navigator window onto the chart.
   - Configure the inputs in the EA’s settings dialog if necessary.
   - Enable automated trading in MetaTrader 5.
   - Attach the EA to a chart on either the M10 or H1 timeframe.
   - Configure input parameters (e.g., lot size, stop loss, take profit, confidence level). Set mode = 1 to pull signal data through API.
   - The EA will pull data from FxChartAI using API, process the signals, and execute trades based on the implemented logic.
   - Monitor the Experts log for messages regarding trade decisions and error handling.

## Contributing

We welcome contributions from the community to improve the FxChartAI Algorithm Trading EA. If you have ideas or improvements that can help the algorithm reach 100% accurate trade decisions, please:

- Fork this repository.
- Create a feature branch and implement your changes.
- Submit a pull request with detailed information about your changes. Test report with optimised input values can be submitted as changes to `reports/`.
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

