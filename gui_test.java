import org.nlogo.app.App;
public class gui_test {
    public static void main(String[] argv) {
        App.main(argv);
        try {
            java.awt.EventQueue.invokeAndWait(
                    new Runnable() {
                        public void run() {
                            try {
                                App.app().open(
                                        "environment-622.nlogo",true);
                            }
                            catch(java.io.IOException ex) {
                                ex.printStackTrace();
                            }}});
            App.app().command("setup");
            App.app().command("go");
            System.out.println(
                    //App.app().report("burned-trees")
                    );
        }
        catch(Exception ex) {
            ex.printStackTrace();
        }
    }
}