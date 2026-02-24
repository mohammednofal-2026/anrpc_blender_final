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

  double totalLevel = 0.0, ethyl135 = 0.0, finalDen = 0.0, finalAr = 0.0, 
         finalBen = 0.0, finalRvp = 0.0, finalOle = 0.0, finalS = 0.0, finalSens = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadSavedData(); // استرجاع البيانات المحفوظة عند التشغيل
  }

  void _initializeData() {
    rowsData = List.generate(rowCount, (index) {
      var row = <String, TextEditingController>{};
      ['tank', 'prod', 'level', 'oct', 'sens', 'den', 'ar', 'ben', 'ole', 'rvp', 's']
          .forEach((key) {
        row[key] = TextEditingController();
        // الحفظ التلقائي عند كل تغيير
        row[key]!.addListener(() {
          _saveData(); 
          _calculateAll();
        });
      });
      return row;
    });
  }

  // دالة حفظ البيانات في ذاكرة الهاتف
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

  // دالة استرجاع البيانات
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      productGrade = prefs.getString('productGrade') ?? "95";
      season = prefs.getString('season') ?? "Summer";
      for (int i = 0; i < rowCount; i++) {
        rowsData[i].forEach((key, controller) {
          controller.text = prefs.getString('row_${i}_$key') ?? ( (key == 'tank' || key == 'prod') ? '' : '0');
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
      // معادلة الـ Ethyl Octane باستخدام الـ Olefins والـ Sensitivity
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
      if (type == "SENS") return val >= 10 ? Colors.greenAccent : Colors.redAccent;
      if (type == "S") return val <= 10 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 1.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 42 ? Colors.greenAccent : Colors.redAccent;
      if (type == "OLE") return val <= 18 ? Colors.greenAccent : Colors.redAccent;
      if (type == "RVP") return val <= rvpLimit ? Colors.greenAccent : Colors.redAccent;
    } else {
      if (type == "OCT") return val >= 92 ? Colors.greenAccent : Colors.redAccent;
      if (type == "SENS") return val >= 8.1 ? Colors.greenAccent : Colors.redAccent;
      if (type == "S") return val <= 150 ? Colors.greenAccent : Colors.redAccent;
      if (type == "BEN") return val <= 3.0 ? Colors.greenAccent : Colors.redAccent;
      if (type == "AR") return val <= 42 ? Colors.greenAccent : Colors.redAccent;
      if (type == "OLE") return val <= 18 ? Colors.greenAccent : Colors.redAccent;
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
        title: Text("Gas Pro Blending", style: TextStyle(fontSize: 14)),
        actions: [
          DropdownButton<String>(
            value: season,
            underline: Container(),
            items: ["Summer", "Winter"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) { setState(() => season = v!); _saveData(); },
          ),
          DropdownButton<String>(
            value: productGrade,
            underline: Container(),
            items: ["92", "95"].map((s) => DropdownMenuItem(value: s, child: Text(" G-$s ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
            onChanged: (v) { setState(() => productGrade = v!); _saveData(); },
          ),
          IconButton(icon: Icon(Icons.print, color: Colors.orangeAccent), onPressed: _showRecipeDialog),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                  child: DataTable(
                    columnSpacing: 8,
                    horizontalMargin: 5,
                    headingRowHeight: 40,
                    dataRowHeight: 32,
                    headingRowColor: MaterialStateProperty.all(Colors.blueGrey[800]),
                    border: TableBorder.all(color: Colors.grey[800]!),
                    columns: ['Tank', 'Prod', 'Level', 'Oct', 'Sens', 'Ole%', 'Ar%', 'Ben%', 'RVP', 'S']
                        .map((h) => DataColumn(label: Text(h, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)))).toList(),
                    rows: rowsData.map((row) => DataRow(cells: [
                      _inputCell(row['tank']!, 45, true), _inputCell(row['prod']!, 55, true),
                      _inputCell(row['level']!, 40, false), _inputCell(row['oct']!, 35, false),
                      _inputCell(row['sens']!, 35, false), _inputCell(row['ole']!, 35, false),
                      _inputCell(row['ar']!, 35, false), _inputCell(row['ben']!, 35, false),
                      _inputCell(row['rvp']!, 40, false), _inputCell(row['s']!, 35, false),
                    ])).toList(),
                  ),
                ),
              ),
              _buildFinalSpecPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinalSpecPanel() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
      ),
      child: Wrap(
        spacing: 15, runSpacing: 12, alignment: WrapAlignment.center,
        children: [
          _specItem("ETHYL OCT", ethyl135.toStringAsFixed(2), _getSpecColor("OCT", ethyl135)),
          _specItem("SENSITIVITY", finalSens.toStringAsFixed(1), _getSpecColor("SENS", finalSens)),
          _specItem("OLEFINS", "${finalOle.toStringAsFixed(1)}%", _getSpecColor("OLE", finalOle)),
          _specItem("AROMATICS", "${finalAr.toStringAsFixed(1)}%", _getSpecColor("AR", finalAr)),
          _specItem("BENZENE", "${finalBen.toStringAsFixed(2)}%", _getSpecColor("BEN", finalBen)),
          _specItem("RVP", finalRvp.toStringAsFixed(2), _getSpecColor("RVP", finalRvp)),
          _specItem("SULFUR", "${finalS.toStringAsFixed(0)}", _getSpecColor("S", finalS)),
          _specItem("LEVEL", "${totalLevel.toStringAsFixed(0)}", Colors.white),
        ],
      ),
    );
  }

  Widget _specItem(String label, String value, Color color) => Column(
    children: [
      Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 8)),
      Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
    ],
  );

  DataCell _inputCell(TextEditingController c, double w, bool isTxt) => DataCell(
    Container(width: w, child: TextField(
      controller: c, textAlign: TextAlign.center,
      style: TextStyle(fontSize: 10),
      keyboardType: isTxt ? TextInputType.text : TextInputType.number,
      decoration: InputDecoration(border: InputBorder.none),
    )),
  );

  void _showRecipeDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.all(10),
      content: Screenshot(
        controller: screenshotController,
        child: Container(
          width: 500, color: Colors.white, padding: EdgeInsets.all(15),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("GASOLINE BLENDING RECIPE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                Text("App by Mohammed Nofal", style: TextStyle(color: Colors.blue[900], fontSize: 10, fontWeight: FontWeight.bold)),
                Divider(color: Colors.black45),
                _recipeTable(),
                SizedBox(height: 12),
                _recipeBox(),
                SizedBox(height: 8),
                Text("Saved at: ${DateTime.now().toString().substring(0,16)}", style: TextStyle(color: Colors.grey, fontSize: 7)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Close")),
        ElevatedButton(onPressed: _saveImg, child: Text("Save to Gallery")),
      ],
    ));
  }

  Widget _recipeBox() => Container(
    padding: EdgeInsets.all(8),
    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.grey[300]!)),
    child: Column(
      children: [
        _recipeRow("PRODUCT GRADE", "$productGrade ($season)"),
        _recipeRow("FINAL ETHYL OCTANE", ethyl135.toStringAsFixed(2)),
        _recipeRow("FINAL OLEFINS %", finalOle.toStringAsFixed(1)),
        _recipeRow("FINAL SULFUR", finalS.toStringAsFixed(1)),
        _recipeRow("FINAL RVP", finalRvp.toStringAsFixed(2)),
        _recipeRow("TOTAL LEVEL", "${totalLevel.toStringAsFixed(1)} cm"),
      ],
    ),
  );

  Widget _recipeRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: Colors.black87, fontSize: 10)), Text(v, style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold))]),
  );

  Widget _recipeTable() => Table(
    border: TableBorder.all(color: Colors.black26),
    children: [
      TableRow(decoration: BoxDecoration(color: Colors.grey[300]), children: [_th("Tank"), _th("Prod"), _th("Level"), _th("Oct")]),
      ...rowsData.where((r) => (double.tryParse(r['level']!.text) ?? 0) > 0).map((r) => TableRow(
        children: [_td(r['tank']!.text), _td(r['prod']!.text), _td(r['level']!.text), _td(r['oct']!.text)],
      )).toList()
    ],
  );

  Widget _th(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center));
  Widget _td(String t) => Padding(padding: EdgeInsets.all(4), child: Text(t, style: TextStyle(color: Colors.black, fontSize: 9), textAlign: TextAlign.center));

  void _saveImg() async {
    final image = await screenshotController.capture();
    if (image != null) {
      await ImageGallerySaver.saveImage(image);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Recipe Saved Successfully!")));
    }
  }
}
