import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
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
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      productGrade = prefs.getString('productGrade') ?? "95";
      season = prefs.getString('season') ?? "Summer";
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
      avgOct = wOct; // Volume Average Octane
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: Colors.blueGrey[900],
        centerTitle: true,
        title: Text("Gasoline Blender Tool", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            value: season, underline: Container(),
            items: ["Summer", "Winter"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
            onChanged: (v) { setState(() => season = v!); _saveData(); },
          ),
        ),
        actions: [
          DropdownButton<String>(
            value: productGrade, underline: Container(),
            items: ["92", "95"].map((s) => DropdownMenuItem(value: s, child: Text("G-$s", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent)))).toList(),
            onChanged: (v) { setState(() => productGrade = v!); _saveData(); },
          ),
          IconButton(icon: Icon(Icons.print, color: Colors.greenAccent), onPressed: _showRecipeDialog),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 8, horizontalMargin: 4, headingRowHeight: 40, dataRowHeight: 32,
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
                    DataRow(color: MaterialStateProperty.all(Colors.blueGrey[900]), cells: [
                      DataCell(Text("FINAL", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 8))),
                      DataCell(Text("BLENDING", style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold))),
                      DataCell(Text(totalLevel.toStringAsFixed(0), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                      DataCell(_specBox(avgOct.toStringAsFixed(1), _getSpecColor("OCT", avgOct))), // Volume Average Octane
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
              _buildDashboard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      width: double.infinity, margin: EdgeInsets.all(10), padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blueGrey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orangeAccent.withOpacity(0.4))),
      child: Wrap(
        spacing: 15, runSpacing: 15, alignment: WrapAlignment.center,
        children: [
          _dashItem("Level", totalLevel.toStringAsFixed(0), Colors.white),
          _dashItem("Ethyl Octane", ethyl135.toStringAsFixed(2), _getSpecColor("OCT", ethyl135)),
          _dashItem("Density", finalDen.toStringAsFixed(4), Colors.cyanAccent),
          _dashItem("AR %", "${finalAr.toStringAsFixed(1)}%", _getSpecColor("AR", finalAr)),
          _dashItem("Ben %", "${finalBen.toStringAsFixed(2)}%", _getSpecColor("BEN", finalBen)),
          _dashItem("RVP", finalRvp.toStringAsFixed(2), _getSpecColor("RVP", finalRvp)),
        ],
      ),
    );
  }

  Widget _dashItem(String label, String val, Color col) => Column(children: [
    Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 8, fontWeight: FontWeight.bold)),
    Text(val, style: TextStyle(color: col, fontSize: 13, fontWeight: FontWeight.bold)),
  ]);

  Widget _specBox(String t, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.1), border: Border.all(color: c, width: 0.8)),
    child: Text(t, style: TextStyle(color: c, fontSize: 8.5, fontWeight: FontWeight.bold)),
  );

  DataCell _inputCell(TextEditingController c, double w, bool isTxt) => DataCell(
    Container(width: w, child: TextField(
      controller: c, textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
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
          width: 500, color: Colors.white, padding: EdgeInsets.all(18),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text("GASOLINE BLENDING RECIPE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
              Text("G-$productGrade Specification Report", style: TextStyle(color: Colors.blue[900], fontSize: 11, fontWeight: FontWeight.bold)),
              Divider(color: Colors.black45, thickness: 1.5),
              _recipeTable(),
              SizedBox(height: 15),
              _recipeInfoBox(),
              SizedBox(height: 25),
              Divider(color: Colors.black26),
              Align(alignment: Alignment.centerRight, child: Text("ANRPC Production Planning Team", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))),
              Align(alignment: Alignment.centerRight, child: Text("App by Mohammed Nofal", style: TextStyle(color: Colors.blueGrey, fontSize: 8, fontStyle: FontStyle.italic))),
            ]),
          ),
        ),
      ),
      actions: [ElevatedButton(onPressed: _saveImg, child: Text("Save to Gallery"))],
    ));
  }

  Widget _recipeTable() => Table(
    border: TableBorder.all(color: Colors.black45),
    children: [
      TableRow(decoration: BoxDecoration(color: Colors.grey[300]), children: [_th("Tanks"), _th("Prod."), _th("Level"), _th("OCT")]),
      ...rowsData.where((r) => (double.tryParse(r['level']!.text) ?? 0) > 0).map((r) => TableRow(
        children: [_td(r['tank']!.text), _td(r['prod']!.text), _td(r['level']!.text), _td(r['oct']!.text)],
      )).toList()
    ],
  );

  Widget _recipeInfoBox() => Container(
    padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.grey[300]!)),
    child: Column(children: [
      _rRow("Ethyl Octane (Calculated)", ethyl135.toStringAsFixed(2)),
      _rRow("Vol. Avg. Octane", avgOct.toStringAsFixed(1)),
      _rRow("Density @15C", finalDen.toStringAsFixed(4)),
      _rRow("Aromatics %", finalAr.toStringAsFixed(1)),
      _rRow("Benzene %", finalBen.toStringAsFixed(2)),
      _rRow("RVP ($season)", finalRvp.toStringAsFixed(2)),
      Divider(),
      _rRow("Total Batch Level", "${totalLevel.toStringAsFixed(0)} cm", isBold: true),
    ]),
  );

  Widget _rRow(String l, String v, {bool isBold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)), Text(v, style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))]));
  Widget _th(String t) => Padding(padding: EdgeInsets.all(5), child: Text(t, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center));
  Widget _td(String t) => Padding(padding: EdgeInsets.all(5), child: Text(t, style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w500), textAlign: TextAlign.center));

  void _saveImg() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await ImageGallerySaver.saveImage(image);
      Navigator.pop(context);
    }
  }
}
