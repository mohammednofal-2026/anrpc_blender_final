import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: GasolineProCalculator(),
    ));

class GasolineProCalculator extends StatefulWidget {
  @override
  _GasolineProCalculatorState createState() => _GasolineProCalculatorState();
}

class _GasolineProCalculatorState extends State<GasolineProCalculator> {
  final int rowCount = 8;
  late List<Map<String, TextEditingController>> rowsData;
  final ScreenshotController screenshotController = ScreenshotController();
  
  String productGrade = "95";
  String season = "Summer"; 
  final TextEditingController blendingTankController = TextEditingController(text: "Tank 1");

  double totalLevel = 0.0, avgOct = 0.0, ethyl135 = 0.0, finalDen = 0.0, finalAr = 0.0, 
         finalBen = 0.0, finalRvp = 0.0, finalOle = 0.0, finalS = 0.0, finalSens = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadSavedData();
  }

  void _initializeData() {
    rowsData = List.generate(rowCount, (index) {
      var row = <String, TextEditingController>{};
      ['tank', 'prod', 'level', 'oct', 'sens', 'den', 'ar', 'ben', 'ole', 's', 'rvp']
          .forEach((key) {
        row[key] = TextEditingController();
        row[key]!.addListener(() {
          _saveData(); 
          _calculateAll();
        });
      });
      return row;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < rowCount; i++) {
      rowsData[i].forEach((key, controller) {
        prefs.setString('row_${i}_$key', controller.text);
      });
    }
    prefs.setString('productGrade', productGrade);
    prefs.setString('season', season);
    prefs.setString('blendingTank', blendingTankController.text);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      productGrade = prefs.getString('productGrade') ?? "95";
      season = prefs.getString('season') ?? "Summer";
      blendingTankController.text = prefs.getString('blendingTank') ?? "Tank 1";
      for (int i = 0; i < rowCount; i++) {
        rowsData[i].forEach((key, controller) {
          controller.text = prefs.getString('row_${i}_$key') ?? ((key == 'tank' || key == 'prod') ? '' : '0');
        });
      }
    });
    _calculateAll();
  }

  void _calculateAll() {
    double tLvl = 0, wOct = 0, wSens = 0, wDen = 0, wAr = 0, wBen = 0, wOle = 0, wS = 0, rvpSum = 0;
    double sumRJ = 0, sumO2 = 0;

    for (var r in rowsData) tLvl += double.tryParse(r["level"]!.text) ?? 0;

    if (tLvl > 0) {
      for (var r in rowsData) {
        double l = double.tryParse(r["level"]!.text) ?? 0;
        double ratio = l / tLvl;
        double oct = double.tryParse(r["oct"]!.text) ?? 0;
        double sens = double.tryParse(r["sens"]!.text) ?? 0;
        double ole = double.tryParse(r["ole"]!.text) ?? 0;

        wOct += ratio * oct;
        wSens += ratio * sens;
        wDen += ratio * (double.tryParse(r["den"]!.text) ?? 0);
        wAr += ratio * (double.tryParse(r["ar"]!.text) ?? 0);
        wBen += ratio * (double.tryParse(r["ben"]!.text) ?? 0);
        wOle += ratio * ole;
        wS += ratio * (double.tryParse(r["s"]!.text) ?? 0);
        sumRJ += ratio * oct * sens;
        sumO2 += ratio * pow(ole, 2);
        double rvp = double.tryParse(r["rvp"]!.text) ?? 0;
        if (rvp > 0) rvpSum += ratio * pow(rvp, 1.25);
      }
      avgOct = wOct; 
      ethyl135 = wOct + (0.03324 * (sumRJ - (wOct * wSens))) + (0.00085 * (sumO2 - pow(wOle, 2)));
    }
    setState(() {
      totalLevel = tLvl; finalSens = wSens; finalDen = wDen;
      finalAr = wAr; finalBen = wBen; finalOle = wOle; finalS = wS;
      finalRvp = tLvl > 0 ? pow(rvpSum, 1 / 1.25).toDouble() : 0;
    });
  }

  Color _getSpecColor(String type, double val) {
    double rvpLimit = (season == "Summer") ? 0.63 : 0.72;
    if (productGrade == "95") {
      if (type == "OCT") return val >= 95 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 1.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 42 ? Colors.greenAccent : Colors.redAccent;
      if (type == "RVP") return val <= rvpLimit ? Colors.greenAccent : Colors.redAccent;
    } else {
      if (type == "OCT") return val >= 92 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 3.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 42 ? Colors.greenAccent : Colors.redAccent;
      if (type == "RVP") return val <= rvpLimit ? Colors.greenAccent : Colors.redAccent;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(110),
        child: AppBar(
          backgroundColor: Colors.blueGrey[900],
          elevation: 10,
          flexibleSpace: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Gasoline Blending Tool", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.orangeAccent)),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Blending Tank Input
                      Container(
                        width: 90,
                        height: 35,
                        child: TextField(
                          controller: blendingTankController,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: "Blend Tank",
                            labelStyle: TextStyle(color: Colors.grey, fontSize: 10),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 5),
                          ),
                          onChanged: (v) => _saveData(),
                        ),
                      ),
                      // Season Dropdown
                      DropdownButton<String>(
                        value: season, underline: Container(),
                        dropdownColor: Colors.blueGrey[800],
                        items: ["Summer", "Winter"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (v) { setState(() => season = v!); _saveData(); },
                      ),
                      // Grade Dropdown
                      DropdownButton<String>(
                        value: productGrade, underline: Container(),
                        dropdownColor: Colors.blueGrey[800],
                        items: ["92", "95"].map((s) => DropdownMenuItem(value: s, child: Text("G-$s", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent)))).toList(),
                        onChanged: (v) { setState(() => productGrade = v!); _saveData(); },
                      ),
                      IconButton(icon: Icon(Icons.picture_as_pdf, color: Colors.orangeAccent, size: 20), onPressed: _showRecipeDialog),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Table Container with horizontal scroll for small screens
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columnSpacing: constraints.maxWidth > 600 ? 20 : 8,
                      horizontalMargin: 4,
                      headingRowHeight: 40,
                      dataRowHeight: 32,
                      headingRowColor: MaterialStateProperty.all(Colors.blueGrey[800]),
                      border: TableBorder.all(color: Colors.grey[800]!),
                      columns: ['Tanks', 'Prod.', 'level', 'OCT', 'Sens.', 'Dens', 'AR%', 'Ben%', 'Ole%', 'S%', 'RVP']
                          .map((h) => DataColumn(label: Text(h, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)))).toList(),
                      rows: [
                        ...rowsData.map((row) => DataRow(cells: [
                          _inputCell(row['tank']!, 45, true), _inputCell(row['prod']!, 55, true),
                          _inputCell(row['level']!, 40, false), _inputCell(row['oct']!, 35, false),
                          _inputCell(row['sens']!, 30, false), _inputCell(row['den']!, 45, false),
                          _inputCell(row['ar']!, 30, false), _inputCell(row['ben']!, 30, false),
                          _inputCell(row['ole']!, 30, false), _inputCell(row['s']!, 30, false),
                          _inputCell(row['rvp']!, 40, false),
                        ])).toList(),
                        // Final Blending Row
                        DataRow(color: MaterialStateProperty.all(Colors.blueGrey[900]), cells: [
                          DataCell(Text("FINAL", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 8))),
                          DataCell(Text("BLENDING", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold))),
                          DataCell(Text(totalLevel.toStringAsFixed(0), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                          DataCell(_specBox(avgOct.toStringAsFixed(1), _getSpecColor("OCT", avgOct))),
                          DataCell(Text(finalSens.toStringAsFixed(1), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                          DataCell(Text(finalDen.toStringAsFixed(4), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                          DataCell(_specBox(finalAr.toStringAsFixed(1), _getSpecColor("AR", finalAr))),
                          DataCell(_specBox(finalBen.toStringAsFixed(2), _getSpecColor("BEN", finalBen))),
                          DataCell(Text(finalOle.toStringAsFixed(1), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                          DataCell(Text(finalS.toStringAsFixed(0), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                          DataCell(_specBox(finalRvp.toStringAsFixed(2), _getSpecColor("RVP", finalRvp))),
                        ]),
                      ],
                    ),
                  ),
                ),
                _buildDashboard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      width: double.infinity, margin: EdgeInsets.all(12), padding: EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.blueGrey[900], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 2)),
      child: Wrap(
        spacing: 20, runSpacing: 20, alignment: WrapAlignment.center,
        children: [
          _dashItem("Total Level", "${totalLevel.toStringAsFixed(0)} cm", Colors.white),
          _dashItem("Ethyl Octane", ethyl135.toStringAsFixed(2), _getSpecColor("OCT", ethyl135)),
          _dashItem("Density @15", finalDen.toStringAsFixed(4), Colors.cyanAccent),
          _dashItem("Aromatics %", "${finalAr.toStringAsFixed(1)}%", _getSpecColor("AR", finalAr)),
          _dashItem("Benzene %", "${finalBen.toStringAsFixed(2)}%", _getSpecColor("BEN", finalBen)),
          _dashItem("RVP", finalRvp.toStringAsFixed(2), _getSpecColor("RVP", finalRvp)),
        ],
      ),
    );
  }

  Widget _dashItem(String label, String val, Color col) => Column(children: [
    Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 9, fontWeight: FontWeight.bold)),
    SizedBox(height: 4),
    Text(val, style: TextStyle(color: col, fontSize: 15, fontWeight: FontWeight.bold)),
  ]);

  Widget _specBox(String t, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.1), border: Border.all(color: c, width: 1)),
    child: Text(t, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold)),
  );

  DataCell _inputCell(TextEditingController c, double w, bool isTxt) => DataCell(
    Container(width: w, child: TextField(
      controller: c, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      keyboardType: isTxt ? TextInputType.text : TextInputType.number,
      decoration: InputDecoration(border: InputBorder.none),
    )),
  );

  void _showRecipeDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Colors.white, insetPadding: EdgeInsets.all(10),
      content: Screenshot(
        controller: screenshotController,
        child: Container(
          width: 500, color: Colors.white, padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text("GASOLINE BLENDING RECIPE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
              Text("${blendingTankController.text} - G$productGrade ($season)", style: TextStyle(color: Colors.blue[900], fontSize: 12, fontWeight: FontWeight.bold)),
              Divider(color: Colors.black45, thickness: 2),
              _recipeTable(),
              SizedBox(height: 20),
              _recipeInfoBox(),
              SizedBox(height: 40),
              Align(alignment: Alignment.centerRight, child: Text("ANRPC Production Planning Team", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))),
              Align(alignment: Alignment.centerRight, child: Text("App by Mohammed Nofal", style: TextStyle(color: Colors.blueGrey[600], fontSize: 9, fontStyle: FontStyle.italic))),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.red))),
        ElevatedButton(onPressed: _saveImg, child: Text("Export Image")),
      ],
    ));
  }

  Widget _recipeTable() => Table(
    border: TableBorder.all(color: Colors.black54),
    children: [
      TableRow(decoration: BoxDecoration(color: Colors.grey[300]), children: [_th("Tanks"), _th("Prod."), _th("Level"), _th("OCT")]),
      ...rowsData.where((r) => (double.tryParse(r['level']!.text) ?? 0) > 0).map((r) => TableRow(
        children: [_td(r['tank']!.text), _td(r['prod']!.text), _td(r['level']!.text), _td(r['oct']!.text)],
      )).toList()
    ],
  );

  Widget _recipeInfoBox() => Container(
    padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[400]!)),
    child: Column(children: [
      _rRow("Ethyl Octane (Final)", ethyl135.toStringAsFixed(2)),
      _rRow("Density @ 15.0 C", finalDen.toStringAsFixed(4)),
      _rRow("Aromatics Vol %", finalAr.toStringAsFixed(1)),
      _rRow("Benzene Vol %", finalBen.toStringAsFixed(2)),
      _rRow("RVP Pressure", finalRvp.toStringAsFixed(2)),
      _rRow("Olefins Vol %", finalOle.toStringAsFixed(1)),
      Divider(thickness: 1),
      _rRow("Total Batch Level", "${totalLevel.toStringAsFixed(0)} cm", isBold: true),
    ]),
  );

  Widget _rRow(String l, String v, {bool isBold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)), Text(v, style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))]));
  Widget _th(String t) => Padding(padding: EdgeInsets.all(6), child: Text(t, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center));
  Widget _td(String t) => Padding(padding: EdgeInsets.all(6), child: Text(t, style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center));

  void _saveImg() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await ImageGallerySaver.saveImage(image);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Recipe Saved to Gallery!")));
    }
  }
}
